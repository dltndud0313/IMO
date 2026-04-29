# 백엔드 배포 계획 (S14P31C203 / C203 EC2)

> **작성일**: 2026-04-29
> **선행 문서**: [backend_roadmap.md](backend_roadmap.md), [backend_summary.md](backend_summary.md)
> **현재 상태**: Phase 1~7 코드 변경 완료 + 로컬 검증 종료, EC2 .pem 수령
> **이 문서의 범위**: Task 2-1 EC2 수동 배포 → 2-2 Nginx+HTTPS → 3-1 Jenkins → 3-2 MM 알림

---

## 0. 핵심 결정 사항 (이번 라운드 기준)

| # | 항목 | 결정 |
|---|------|------|
| 1 | Redis 통합 vs EC2 배포 순서 | **EC2 먼저, Redis는 후속** |
| 2 | 외부 노출 형태 | `8000` 직접 노출 X → **Nginx 리버스 프록시 → 443(HTTPS)** |
| 3 | HTTPS 적용 | **적용** (Let's Encrypt + certbot, 호스트 설치 방식) |
| 4 | 도메인 | **k14c203.p.ssafy.io** (SSAFY 제공 도메인 그대로) |
| 5 | DB | EC2 안 도커 Postgres (별도 RDS 분리는 v1.1+) |
| 6 | Jenkins | EC2에 직접 설치, **포트 9090** (Gerrit이 8989에 떠 있어 충돌 회피) |
| 7 | 알림 | Mattermost Incoming Webhook |

> Redis 결정 근거: 백엔드가 이미 안정 상태라 "현재 상태를 한 번 EC2에서 성공시키고" 그 위에 Redis를 얹는 게 디버깅 분리에 유리. Redis는 read-through 캐싱이라 후속 추가에도 동작이 깨지지 않음.

---

## 1. 목표 아키텍처

```
[클라이언트(앱/브라우저)]
        │  HTTPS:443
        ▼
   ┌────────────────┐
   │  Nginx (host)  │  ── certbot 자동 갱신
   │  80 → 443 리다이렉트│
   └────┬───────────┘
        │  proxy_pass http://127.0.0.1:8000
        ▼
   ┌────────────────────────────────┐
   │  api 컨테이너 (uvicorn:8000)   │  127.0.0.1 바인딩만 (외부 미노출)
   └────┬───────────────────────────┘
        │  imo_net (도커 내부 네트워크)
        ▼
   ┌────────────────────────────────┐
   │  db 컨테이너 (postgres:15)     │  외부 미노출
   └────────────────────────────────┘

   (후속) ┌────────────────────────────────┐
          │  redis 컨테이너 (redis:7)       │  외부 미노출
          └────────────────────────────────┘

   (후속) ┌────────────────────────────────┐
          │  Jenkins (host or 컨테이너)     │  9090, UFW 화이트리스트
          └────────────────────────────────┘
```

**원칙**
- `api`, `db`, (`redis`)는 외부 포트 매핑 제거 — `imo_net` 안에서만 통신
- Nginx만 80/443으로 외부 노출
- DB 포트(5432), API 포트(8000)는 절대 외부 노출 X

---

## 2. EC2 / 접속 정보

| 항목 | 값 |
|------|----|
| 분반 | C203 / K14C203 |
| SSH | `ssh -i K14C203T.pem ubuntu@k14c203.p.ssafy.io` |
| 도메인 | `k14c203.p.ssafy.io` |
| 외부 노출 포트 | 22 (SSH), 80 (HTTP→리다이렉트), 443 (HTTPS), 9090 (Jenkins, IP 제한 권장) |
| 충돌 회피 포트 | **8989** (Gerrit), 8000/5432/6379 (전부 내부 전용) |

> **주의**: SSAFY 안내상 UFW는 반드시 `enable` 상태로 유지. 여기 적힌 포트 외에는 열지 않는다.

---

## 3. 단계별 진행 계획

### Phase 1. EC2 기본 환경 셋업 (예상 30~60분)

**목표**: Docker / Compose / Nginx / certbot 설치, UFW 정책 확립.

```bash
# 로컬에서
ssh -i K14C203T.pem ubuntu@k14c203.p.ssafy.io
```

EC2 안에서 (한 번에 끝나는 묶음):

```bash
# 1) 패키지 갱신 + 기본 도구
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg git ufw nginx

# 2) Docker 공식 저장소 + 엔진/컴포즈 플러그인
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3) sudo 없이 docker 쓰기 (재로그인 필요)
sudo usermod -aG docker $USER

# 4) UFW: enable 상태에서 SSH 끊기지 않도록 22 먼저 열고 enable
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status   # 현재 inactive 면 enable
sudo ufw --force enable
sudo ufw status verbose
```

**완료 기준**:
- `docker compose version` 정상
- `sudo ufw status` 가 `active` + 22/80/443 ALLOW
- `nginx -v` 정상

> **재로그인 필수**: `usermod -aG docker` 반영을 위해 ssh 재접속.

---

### Phase 2. 백엔드 컨테이너 배포 (예상 1~2시간)

**목표**: api + db 가 EC2에서 컨테이너로 기동, 8000은 외부 차단.

**2-1. 코드 배포**

C206 때처럼 `~/S14P31C203` 에 Git clone. (초기 1회는 `feature/backend-spec-alignment` 또는 머지된 `develop` 기준)

```bash
cd ~
git clone <gitlab-repo-url-with-PAT> S14P31C203
cd S14P31C203
git checkout develop
```

> GitLab SSH(22)는 EC2에서 timeout 가능성 있음 (C206 사례). HTTPS + Personal Access Token 방식 권장.

**2-2. EC2용 compose 파일 분리**

기존 `backend/docker-compose.yml` 은 개발용(`./:/app` volume + 포트 노출). EC2용으로 신규 파일 추가:

`backend/docker-compose.ec2.yml`:

```yaml
services:
  api:
    build: .
    restart: always
    # 외부 노출 X — Nginx 가 127.0.0.1:8000 으로만 prox_pass
    expose:
      - "8000"
    ports:
      - "127.0.0.1:8000:8000"   # 호스트 nginx 가 접근 가능하도록 loopback 만 바인딩
    environment:
      - DATABASE_URL=postgresql+asyncpg://imo_user:${POSTGRES_PASSWORD}@db:5432/imo_db
      - JWT_SECRET=${JWT_SECRET}
      - JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
      - CORS_ORIGINS=${CORS_ORIGINS:-*}
    depends_on:
      - db
    networks:
      - imo_net
    # 운영: 호스트 코드 마운트 X (이미지 안 코드만 사용)

  db:
    image: postgres:15-alpine
    restart: always
    environment:
      POSTGRES_USER: imo_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: imo_db
    # 5432 외부 노출 X
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - imo_net

volumes:
  postgres_data:

networks:
  imo_net:
```

**2-3. 운영용 `.env` 작성**

`backend/.env.production` (Git 미커밋, EC2 에서만 작성):

```bash
POSTGRES_PASSWORD=<강한 랜덤 문자열>
JWT_SECRET=<랜덤 32바이트 이상>
JWT_REFRESH_SECRET=<위와 다른 랜덤 32바이트 이상>
CORS_ORIGINS=*
```

> 시크릿 생성 예: `openssl rand -base64 48`

**2-4. 빌드/기동**

```bash
cd ~/S14P31C203/backend
docker compose -f docker-compose.ec2.yml --env-file .env.production build
docker compose -f docker-compose.ec2.yml --env-file .env.production up -d
docker compose -f docker-compose.ec2.yml ps
docker compose -f docker-compose.ec2.yml logs --tail=80 api db
```

**2-5. 헬스체크 (호스트 → 컨테이너)**

```bash
curl -i http://127.0.0.1:8000/                   # 루트
curl -i http://127.0.0.1:8000/api/v1/...         # 골든 패스 일부
```

**완료 기준**:
- api/db 컨테이너 `Up` 상태 + alembic 마이그레이션 로그 정상
- 외부에서 `k14c203.p.ssafy.io:8000` 접근 시 **timeout** (UFW 차단 정상 동작)
- 호스트 안 `127.0.0.1:8000` 헬스체크 200

---

### Phase 3. Nginx 리버스 프록시 + HTTPS (예상 1~2시간)

**목표**: `https://k14c203.p.ssafy.io` 로 접근 시 백엔드까지 정상 프록시.

**3-1. Nginx 사이트 설정 (HTTP 단계 — 인증서 발급용)**

```bash
sudo tee /etc/nginx/sites-available/imo > /dev/null <<'EOF'
server {
    listen 80;
    server_name k14c203.p.ssafy.io;

    # certbot http-01 challenge 경로
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # 그 외는 HTTPS 로 (인증서 발급 후 활성화)
    location / {
        return 301 https://$host$request_uri;
    }
}
EOF

sudo mkdir -p /var/www/certbot
sudo ln -sf /etc/nginx/sites-available/imo /etc/nginx/sites-enabled/imo
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

**3-2. Let's Encrypt 인증서 발급 (certbot)**

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot certonly --webroot -w /var/www/certbot \
  -d k14c203.p.ssafy.io \
  --email <본인이메일> --agree-tos --no-eff-email
```

> 발급 실패 시: 외부에서 `http://k14c203.p.ssafy.io/.well-known/acme-challenge/test` 가 200을 받는지 먼저 확인 (UFW 80 허용 + DNS A 레코드 매핑 확인).

**3-3. Nginx 사이트 설정 (443 + 백엔드 프록시)**

```bash
sudo tee /etc/nginx/sites-available/imo > /dev/null <<'EOF'
server {
    listen 80;
    server_name k14c203.p.ssafy.io;
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://$host$request_uri; }
}

server {
    listen 443 ssl http2;
    server_name k14c203.p.ssafy.io;

    ssl_certificate     /etc/letsencrypt/live/k14c203.p.ssafy.io/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/k14c203.p.ssafy.io/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    client_max_body_size 10m;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }
}
EOF
sudo nginx -t && sudo systemctl reload nginx
```

**3-4. 자동 갱신 확인**

```bash
sudo certbot renew --dry-run
# certbot 패키지가 systemd timer 자동 등록 — 별도 cron 불필요
sudo systemctl list-timers | grep certbot
```

**3-5. 외부에서 검증**

로컬 PC 에서:

```bash
curl -i https://k14c203.p.ssafy.io/
# 200 + 백엔드 응답 확인
```

**완료 기준**:
- `https://k14c203.p.ssafy.io` 정상 응답 (브라우저에 자물쇠 표시)
- `http://k14c203.p.ssafy.io` → 443 으로 리다이렉트
- 외부에서 `k14c203.p.ssafy.io:8000`, `:5432` 모두 timeout

---

### Phase 4. 운영 검증 (예상 30분)

골든 패스 12개 cURL을 EC2 도메인 기준으로 다시 실행.

```bash
BASE=https://k14c203.p.ssafy.io/api/v1
# signup → login → me → settings → sessions POST/GET → statistics … (로컬 검증 스크립트와 동일)
```

> 로컬 검증 시 사용한 스크립트가 있다면 BASE_URL 만 바꿔서 재실행. 없다면 [backend_summary.md](backend_summary.md) 참고.

---

### Phase 5. Redis 통합 (배포 안정화 이후)

[backend_roadmap.md Task 1-2](backend_roadmap.md) 그대로 진행. 다만 EC2 배포가 끝난 시점이라 적용 흐름은 다음과 같이 단순해짐:

1. 로컬에서 Redis 캐싱 코드 작업 (`core/cache.py`, `requirements.txt`)
2. `docker-compose.yml` / `docker-compose.ec2.yml` 양쪽에 redis 서비스 추가
3. 로컬 검증 → 커밋 → develop 머지
4. EC2 에서 `git pull && docker compose -f docker-compose.ec2.yml up -d --build`
5. 캐시 hit/miss 로그 확인

**TTL/무효화 규칙** 은 로드맵 문서 그대로 유지.

---

### Phase 6. Jenkins CI/CD (예상 1~2일)

**목표**: GitLab `develop` 머지 시 자동으로 EC2 빌드/배포/검증/알림.

**6-1. Jenkins 설치 (호스트)**

```bash
sudo apt install -y openjdk-17-jdk
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
  sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins

# Jenkins 포트 변경 (8080 → 9090, 충돌/관습 회피)
sudo sed -i 's|HTTP_PORT=8080|HTTP_PORT=9090|' /etc/default/jenkins || true
# Debian 패키지는 systemd override 가 더 안전:
sudo systemctl edit jenkins
# [Service]
# Environment="JENKINS_PORT=9090"
sudo systemctl daemon-reload
sudo systemctl restart jenkins

# UFW: 9090 허용 (가능하면 SSAFY 망 IP 만)
sudo ufw allow 9090/tcp
```

> Jenkins가 docker 명령을 쓰려면 `sudo usermod -aG docker jenkins` 후 `sudo systemctl restart jenkins`.

**6-2. Jenkinsfile 초안** (`backend/Jenkinsfile`)

```groovy
pipeline {
    agent any
    environment {
        COMPOSE_FILE = 'backend/docker-compose.ec2.yml'
        ENV_FILE     = '/home/ubuntu/S14P31C203/backend/.env.production'
        DEPLOY_DIR   = '/home/ubuntu/S14P31C203'
        MM_WEBHOOK   = credentials('MM_WEBHOOK_URL')
    }
    options { timestamps() }
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Build & Deploy') {
            steps {
                sh '''
                  cd ${DEPLOY_DIR}
                  git fetch origin develop
                  git checkout develop
                  git reset --hard origin/develop
                  cd backend
                  docker compose -f docker-compose.ec2.yml --env-file ${ENV_FILE} build
                  docker compose -f docker-compose.ec2.yml --env-file ${ENV_FILE} up -d
                '''
            }
        }
        stage('Verify') {
            steps {
                sh '''
                  for i in 1 2 3 4 5; do
                    code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/) && \
                      [ "$code" = "200" ] && exit 0 || sleep 3
                  done
                  echo "health check failed"; exit 1
                '''
            }
        }
    }
    post {
        success {
            sh '''curl -X POST "$MM_WEBHOOK" -H 'Content-Type: application/json' \
                  -d "{\\"text\\":\\":jenkins7: 백엔드 배포 성공 — ${BUILD_URL}\\"}"'''
        }
        failure {
            sh '''curl -X POST "$MM_WEBHOOK" -H 'Content-Type: application/json' \
                  -d "{\\"text\\":\\":angry_jenkins: 백엔드 배포 실패 — ${BUILD_URL}\\"}"'''
        }
    }
}
```

**6-3. 트리거**: GitLab 프로젝트 → Settings → Webhooks → Jenkins URL 등록 (push events, develop 브랜치).

> C206 때 발생했던 함정 그대로 재현 가능 — credential username/PAT 정리, /tmp 권한, MM payload escape 등은 같은 방식으로 해결.

---

### Phase 7. Mattermost 알림 (예상 30분)

- MM 채널에서 Incoming Webhook 추가 → URL 발급
- Jenkins → Manage Credentials → "Secret text" 로 `MM_WEBHOOK_URL` 등록
- Jenkinsfile 의 `${MM_WEBHOOK}` 가 자동 사용
- 성공/실패 메시지 포맷, 이모지(`:jenkins7:`, `:angry_jenkins:`) 는 C206 패턴 재사용

---

## 4. 운영 명령어 모음 (치트시트)

### 상태 확인

```bash
cd ~/S14P31C203/backend
docker compose -f docker-compose.ec2.yml ps
docker compose -f docker-compose.ec2.yml logs --tail=100 api db
sudo systemctl status nginx
sudo ufw status verbose
```

### 코드 갱신 (Jenkins 미사용 시 수동)

```bash
cd ~/S14P31C203
git pull origin develop
cd backend
docker compose -f docker-compose.ec2.yml --env-file .env.production build
docker compose -f docker-compose.ec2.yml --env-file .env.production up -d
```

### 인증서 강제 갱신 / 점검

```bash
sudo certbot renew --dry-run
sudo certbot certificates
```

### 컨테이너 정리 (디스크 부족 시)

```bash
docker system df
docker image prune -f
```

---

## 5. UFW / 포트 정책 (절대 어기지 말 것)

| 포트 | 외부 공개 | 용도 |
|------|----------|------|
| 22   | ✅ | SSH (.pem 키만) |
| 80   | ✅ | HTTP → 443 리다이렉트 + ACME challenge |
| 443  | ✅ | HTTPS (Nginx) |
| 9090 | ⚠️ 제한 공개 | Jenkins (가능하면 SSAFY 망 IP 화이트리스트) |
| 8989 | (Gerrit) | SSAFY 기본 — 건드리지 않음 |
| 8000 | ❌ | api (loopback only) |
| 5432 | ❌ | db (도커 네트워크 내부만) |
| 6379 | ❌ | redis 추가 시 (도커 네트워크 내부만) |

> UFW는 enable 유지. 새 포트 열기 전에 반드시 `sudo ufw allow <port>/tcp` 후 `status` 확인.

---

## 6. 보안 / 운영 주의사항

- `.pem`, `.env.production`, MM Webhook URL, PAT 절대 Git 커밋 X
- `.env.production` 권한 강화: `chmod 600 .env.production`
- `_dev_sample_session.json` 같은 개발 데이터는 EC2 폴더에 두지 않음
- `/home`, 시스템 디렉토리 퍼미션 임의 변경 금지 (SSAFY 정책)
- SSH 키 분실/누출 시 즉시 SSAFY 운영팀에 초기화 요청 — 직접 복구 불가
- `.ssh_bak` 백업 폴더 존재 — 함부로 삭제 X

---

## 7. 결정 대기 / 외부 의존 항목

| # | 항목 | 결정 필요 시점 |
|---|------|----------------|
| 1 | GitLab 저장소 URL + PAT 발급 | Phase 2 시작 전 |
| 2 | Mattermost Incoming Webhook URL | Phase 7 시작 전 |
| 3 | Jenkins 9090 외부 공개 범위 (전체 vs SSAFY 망 IP) | Phase 6 시작 전 |
| 4 | Redis refresh blacklist 도입 여부 | Phase 5 진행 중 |
| 5 | RDS 분리, 백엔드 다중화 | v1.1 이후 (현재 범위 외) |

---

## 8. 진행 시 참고 문서

- 로드맵 원본: [backend_roadmap.md](backend_roadmap.md)
- 백엔드 변경 이력: [backend_summary.md](backend_summary.md)
- API 명세: [../../docs/IMO_API_Specification.md](../../docs/IMO_API_Specification.md)
- UFW 운영 매뉴얼: 프로젝트 루트의 `ufw 포트 설정하기.txt`

---

## 9. 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| v1.0 | 2026-04-29 | 최초 작성 — Redis 후순위 결정 + Nginx/HTTPS/Jenkins/MM 단계 확정 |
