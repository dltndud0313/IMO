## Git 컨벤션 가이드 작성

### 작성 배경

프로젝트 초기(2026.01.13)에 팀원 5명 중 Git 사용 경험이 부족한 인원이 있었습니다. 충돌·브랜치 꼬임 등의 문제를 사전에 방지하기 위해, 팀원 전원이 바로 따라할 수 있는 수준의 가이드를 작성했습니다.

### 가이드 구성 (15페이지)

| 섹션 | 내용 |
| --- | --- |
| **0. 기본 규칙** | Git 기본 개념 (Repository, Commit, Branch, Remote), 기본 작업 흐름 |
| **1. 처음 레포 받을 때** | `git clone` → 프로젝트 폴더 진입 → 항상 작업 폴더 확인 |
| **2. 매번 작업할 때** | `git switch develop` → develop 브랜치로 이동 후 작업 시작 |
| **3. develop 최신화** | 방식1: `git pull origin develop` (80%, 권장) / 방식2: `fetch + rebase` (20%) |
| **4. 브랜치 전략** | `main`(배포용, 직접 작업 X) ← `develop`(통합) ← `feature/*`(기능별) |
| **5. 커밋 메시지 규칙** | `feat` / `fix` / `refactor` / `docs` / `style` 접두사 + 자주 쓰는 명령어 모음 |
| **6. PR 올리고 Merge** | feature 완료 → PR 생성 → 팀원 리뷰 → approve → develop 머지, 로컬/원격 브랜치 삭제 |
| **7. PR 양식** | 작업 개요(Summary), 세부 작업 내용(Detailed Changes), 테스트 결과, 참고 사항 |
| **8. 상황별 대응법** | 4가지 시나리오별 Best Practice |

### 핵심 규칙 4가지

가이드 상단에 별표로 강조한 4가지 핵심 규칙:

1. **git 컨벤션을 잘 따라 주세요**
2. **merge 시 팀원 모두에 공유하세요**
3. **본인이 작업할 폴더와 현재 위치가 동일한지 확인하세요**
4. **본인이 작업할 브랜치와 현재 위치가 동일한지 확인하세요**

---

## 브랜치 전략

### Git Flow 구조

`master          : 배포용 (직접 작업 절대 X)
  └── develop     : 통합 개발 브랜치
       └── feature/*  : 기능 단위 작업 브랜치`

### 작업 흐름 한 줄 요약

`git clone → git switch develop → git pull → git switch -c feature/xxx → 작업 시작`

### develop 최신화 방법 (2가지)

| 방식 | 명령어 | 사용 비중 | 특징 |
| --- | --- | --- | --- |
| **pull** | `git pull origin develop` | **80%** | 쉽고 안전, 실무 표준, merge 커밋 생길 수 있음 |
| **fetch + rebase** | `git fetch origin` + `git rebase origin/develop` | **20%** | PR 히스토리 깔끔, 강제 푸시 필요할 수 있음 |

팀원 대부분에게는 pull 방식을 권장하고, PR 직전 히스토리 정리가 필요할 때만 rebase를 사용하도록 안내했습니다.

### `git pull origin develop` - 실행 위치에 따른 차이

팀원들이 가장 헷갈려한 부분이 "어디서 `git pull origin develop`을 실행하느냐"였습니다. **실행하는 브랜치에 따라 동작이 다릅니다.**

| 현재 브랜치 | 명령어 | 동작 | 결과 |
| --- | --- | --- | --- |
| `develop` | `git pull origin develop` | 로컬 develop을 원격과 **동기화** | 로컬 develop이 최신 상태가 됨 |
| `feature/xxx` | `git pull origin develop` | 원격 develop을 **현재 feature에 merge** | feature에 merge 커밋 생성, 로컬 develop은 그대로 |

### feature 브랜치에서 develop 최신 반영하기

팀원에게 권장한 정석 워크플로우:

`# 방법 A: 정석 (안전하고 명확)
git switch develop              # develop으로 이동
git pull origin develop         # 로컬 develop 최신화
git switch feature/xxx          # 다시 내 브랜치로
git merge develop               # 최신 develop을 내 브랜치에 반영

# 방법 B: 간편 (결과 동일, 한 줄)
git pull origin develop         # feature 브랜치에서 바로 실행
# → 동작은 같지만, 로컬 develop은 업데이트 안 됨

# 방법 C: PR 직전 (히스토리 정리, 20% 케이스)
git fetch origin
git rebase origin/develop
git push --force-with-lease`

**팀 내 정책:** 방법 A를 기본으로 권장하고, 익숙한 팀원은 방법 B를 허용. 방법 C는 PR 직전에만 사용.

### 추천 루틴

`# 처음 클론 후
git switch develop
git pull origin develop

# 개발 중, 팀원 변경 반영 (방법 A)
git switch develop
git pull origin develop
git switch feature/xxx
git merge develop

# PR 직전 (선택)
git pull origin develop && git push           # 간단하게
# 또는
git fetch origin && git rebase origin/develop && git push --force-with-lease  # 깔끔하게`

---

## 커밋 메시지 규칙

### 접두사 체계

`feat:      로그인 기능 추가
fix:       API 요청 오류 수정
refactor:  컴포넌트 구조 개선
docs:      README 수정
style:     포맷팅 수정`

### 예시

`feat: 비밀번호 찾기 기능 구현
fix: JWT 토큰 만료 시 리다이렉트 오류 수정
refactor: MQTT 브릿지 노드 콜백 구조 개선`

브랜치 이름과 커밋 메시지를 연결하여 기능 단위 추적이 가능하도록 했습니다.

- 브랜치: `feature/frontend-login`
- 커밋: `feat: 로그인 페이지 구현`, `feat: 회원가입 폼 Validation 추가`

---

## PR 프로세스

### PR 양식

`## 작업 개요 (Summary)
개발한 기능의 이름, 목적, 해결하려는 문제

## 세부 작업 내용 (Detailed Changes)
- 새로 만든 앱이나 모델
- 주요 로직 변경
- 설치한 라이브러리나 환경 설정 변경

## 테스트 결과 (Test Results)
- [x] 스크린샷: Postman 응답 화면, 브라우저 화면
- [x] 텍스트 로그: 터미널에 뜬 성공 메시지
- [x] 체크리스트: 내가 확인한 항목들

## 참고 사항 (Notes)
- 실행 전 필수 작업
- 환경 변수
- 미구현 사항/한계`

### PR 규칙

1. PR 올릴 때 **무조건 develop으로 바꿔 올리기** (master/main에 올리면 절대 안 됨)
2. 팀원들은 PR로 소통 → 작업 사항을 반영할지 **approve** 남기기
3. approve 메시지에 **LGTM** 작성
4. **모든 멤버 승인 후** merge 하기

### 실제 PR 예시

프로젝트에서 작성한 PR 예시 (가이드에 스크린샷 포함):

- 제목: `[FE] Feat: 인증 시스템(로그인/회원가입) 구현 및 백엔드 API 연동 #9`
- `feature/frontend-login` → `develop` 으로 8 commits 머지
- Reviewer approve 확인 후 머지 완료

---

## 상황별 대응 가이드

가이드 8번 섹션에 4가지 상황별 Best Practice를 정리했습니다.

### 상황 1: 작업 중인데 develop에 새 기능이 추가됨 (최신화)

`git fetch origin
git rebase origin/develop
# (충돌 발생 시 수정 후)
git add .
git rebase --continue
git push origin feature/xxx --force-with-lease`

- **이유:** 내 커밋들을 최신 develop 위로 옮겨서 히스토리를 직선으로 유지

### 상황 2: PR을 올리기 직전, 마지막으로 점검할 때

`git fetch origin
git rebase origin/develop
git push origin <내-브랜치명> --force`

- **이유:** 리뷰어가 내 코드 변경 사항만 집중해서 볼 수 있도록 불필요한 머지 커밋 제거

### 상황 3: 작업 중 실수로 넣은 파일이나 오타를 수정하고 싶을 때

- 마지막 커밋 수정: `git add .` → `git commit --amend --no-edit`
- 이전 커밋 수정: `git rebase -i HEAD~n` 실행 후 해당 커밋을 `edit`으로 변경
- **이유:** "오타 수정", "누락 파일 추가" 같은 의미 없는 커밋이 쌓이는 것을 방지

### 상황 4: 기능 개발이 완료되어 develop에 내 코드를 합칠 때

`git switch develop
git pull origin develop          # 내 로컬 develop 최신화
git merge <내-브랜치명>           # 내 작업을 develop에 병합
git push origin develop          # 결과 푸시`

- **이유:** "이 기능이 언제 합쳐졌다"는 기록(Merge Commit)을 남겨 프로젝트 흐름을 파악하게 함

### 상황별 도구 선택 요약

| 상황 | 추천 도구 | 결과물 형태 |
| --- | --- | --- |
| 내 브랜치 최신화 | `rebase` | 깔끔한 직선 히스토리 |
| 잘못된 커밋 수정 | `amend` / `rebase -i` | 완벽한 작업 내역 |
| 완료된 기능 통합 | `merge` | 언제 합쳐졌는지 남는 기록 |
| 긴급한 버그 수정 | `cherry-pick` | 특정 커밋만 쏙 뽑아오기 |

---

## 추가 가이드: stash 기반 현업 워크플로우

팀원 질문에 대응하여 **stash를 활용한 브랜치 생성~머지 정석 순서**도 가이드에 추가했습니다.

`# 1단계: 작업물 임시 보관 및 메인 최신화
git stash                              # 하던 작업 임시 보관
git pull origin main                   # 메인 브랜치를 서버 상태와 동기화

# 2단계: 새 브랜치 생성 및 이동
git switch -c feature/my-task          # 새 브랜치 생성과 동시에 이동

# 3단계: 임시 저장물 복원
git stash pop                          # 내 작업물 가져오기

# 4단계: 작업 확정 및 푸시
git add .
git commit -m "feat: 새로운 기능 구현"
git push origin feature/my-task        # 내 브랜치 이름을 명시해서 푸시

# 5단계: 머지(Merge) 하기
git switch main
git merge feature/my-task
git push origin main`

**핵심 팁:** main 브랜치에서 직접 작업하다가 실수로 push하는 것을 방지하기 위해, "최신 코드를 받고 → 내 전용 브랜치를 파서 → 거기서 작업물을 완성"하는 습관을 강조했습니다.

---

## checkout 대신 switch / restore 사용 안내

팀원들에게 **`git checkout` 대신 `git switch`와 `git restore`를 사용하도록 안내**했습니다. `checkout`은 Git 2.23 이전의 옛날 명령어로, 브랜치 이동과 파일 복원을 하나의 명령어로 처리하다 보니 혼동이 잦았습니다.

### checkout → switch / restore 분리

| 옛날 (checkout) | 지금 (분리됨) | 용도 |
| --- | --- | --- |
| `git checkout feature/xxx` | **`git switch feature/xxx`** | 브랜치 이동 |
| `git checkout -b feature/xxx` | **`git switch -c feature/xxx`** | 새 브랜치 생성 + 이동 |
| `git checkout -- file.py` | **`git restore file.py`** | 파일 변경 취소 (되돌리기) |
| `git checkout HEAD~1 file.py` | **`git restore --source HEAD~1 file.py`** | 특정 커밋의 파일로 복원 |

### 왜 분리했나?

`# 옛날: 브랜치 이동인지 파일 복원인지 헷갈림
git checkout develop        # develop 브랜치로 이동? develop 파일 복원?

# 지금: 의도가 명확
git switch develop          # 브랜치 이동
git restore develop.py      # 파일 복원`

### restore 실제 사용 예시

`# 1. 파일 수정했는데 되돌리고 싶을 때
git restore stt_module_fast.py    # 마지막 커밋 상태로 원복

# 2. git add한 파일을 스테이징에서 내리고 싶을 때
git restore --staged file.py      # add 취소 (파일 내용은 유지)

# 3. 특정 커밋 시점의 파일로 복원하고 싶을 때
git restore --source HEAD~3 file.py   # 3커밋 전 버전으로 복원`

팀 컨벤션 가이드의 모든 예시 코드를 `switch` / `restore` 기준으로 작성하여, 팀원들이 자연스럽게 새 명령어를 사용하도록 유도했습니다.

---

## 활용 팁

가이드에 포함한 실용적인 팁:

| 항목 | 내용 |
| --- | --- |
| `.gitignore` | 올리면 안 되는 파일 설정 (빌드 결과물, IDE 설정 등) |
| `.env` | 다운받는 것 중에 안 받아지는 파일 (환경 변수, 시크릿) |
| `git graph` | 자주 확인하여 브랜치 상태 시각적으로 파악 |
| 머지 후 브랜치 삭제 | 원격은 자동 삭제, 로컬은 `git branch -d feature/xxx`로 수동 삭제 |

---

## 실제 Git 트러블슈팅

프로젝트 중 발생한 Git 관련 이슈들을 해결한 사례입니다.

### 1. divergent branches 오류

- **상황:** `git pull origin develop` 시 `divergent branches` 오류 발생
- **원인:** 로컬과 리모트 브랜치가 서로 다른 커밋을 가리키며 분기됨
- **해결:** `git config pull.rebase false` 정책을 팀 전체에 수립하여 merge 방식으로 통일
- **이후:** 가이드에 "80% pull, 20% rebase" 정책을 명시하여 재발 방지

### 2. connect.sh merge conflict

- **상황:** `connect.sh`(Docker 진입 스크립트)에서 팀원 간 다른 버전으로 merge conflict 발생
- **원인:** 각 팀원이 자신의 Docker 컨테이너명을 다르게 설정 (`jjy092801`, `taeyeon` 등)
- **해결:** `git checkout --theirs connect.sh`로 팀 코드를 우선 적용 후 커밋
- **교훈:** 개인 환경 설정 파일은 `.gitignore`에 추가하거나, 환경 변수로 분리하는 것이 바람직

### 3. openni2_redist 유실

- **상황:** `git pull` 후 미추적(untracked) 드라이버 파일이 삭제됨
- **원인:** `.gitignore`에 포함된 디렉토리가 pull 시 초기화
- **해결:** GitHub에서 openni2_redist를 임시 클론하여 복원하는 절차를 수립하고 팀에 공유
- **재발 방지:** Docker 볼륨 마운트로 드라이버를 호스트에서 영구 유지

### 4. 호스트↔Docker 파일 동기화

- **상황:** 3개 환경(Desktop IDE / Jetson Host / Docker)의 경로가 모두 달라 파일 동기화가 안 됨

| 환경 | 경로 |
| --- | --- |
| Desktop IDE | `/home/taeyeon/Desktop/c101/S14P11C101/gae_ws/` |
| Jetson Host | `/home/ssafy/workspaces/taeyeon/S14P11C101/gae_ws/` |
| Docker 내부 | `/root/gae_ws/` |
- **해결:** `docker cp` 기반 파일 전송 워크플로우를 수립`bash # Jetson Host → Docker docker cp /home/ssafy/파일.py taeyeon:/root/gae_ws/src/.../파일.py`
- Desktop에서는 git push → Jetson에서 git pull → Docker에서 빌드하는 파이프라인으로 정리

### 5. 호스트↔Docker 파일 권한 충돌

- **상황:** Docker(root)에서 생성한 파일을 Jetson 호스트(ssafy)에서 편집 시 `Permission denied`
- **원인:** Docker 내부는 root 권한, 호스트는 일반 사용자 권한
- **해결:** 파일 생성/편집은 Docker 내에서 직접 수행, 호스트에서는 `docker cp`로만 전송하는 규칙 수립

### 6. Push 거절 + 4파일 동시 Merge Conflict (non-fast-forward)

- **상황:** PC에서 작업한 코드를 push하려 할 때 `rejected (non-fast-forward)` 에러 발생. pull을 받았더니 `stt_module_fast.py`, `connect.sh` 등 4개 파일에서 `Automatic merge failed` 발생
- **원인:** PC와 Jetson 양쪽에서 같은 파일의 같은 라인을 수정하여 히스토리가 분기(diverged)됨
- **해결:**
- `git status`로 `both modified` 상태 파일 확인
- VS Code에서 `<<<<<<< HEAD`, `=======`, `>>>>>>> origin/...` 충돌 마커를 확인
- 양쪽 코드의 장점을 합친 최종 코드만 남기고 마커 제거
- `git add .` → `git commit -m "fix: resolve merge conflicts"` → `git push`
- **교훈:** PC와 Jetson에서 동시에 같은 파일을 수정하지 않도록, 한쪽에서 작업 완료 후 push → 다른 쪽에서 pull 받는 순서를 팀 규칙으로 정립

### 7. Jetson 로컬 변경으로 인한 Pull 거절 (Aborting)

- **상황:** PC에서 머지를 끝내고 Jetson에서 `git pull`을 했으나, `Your local changes would be overwritten by merge` 에러와 함께 Aborting
- **원인:** Jetson에서 감도 테스트 등을 위해 코드를 임시 수정한 이력이 있어, Git이 덮어쓰기 방지를 위해 pull을 차단
- **해결:**
- `git diff`로 로컬 변경 사항 확인 (중요한 수정인지 판단)
- 필요 시 `cp`로 로컬 파일 백업
- `git fetch origin` → `git reset --hard origin/feature/aivoice_taeyeon`으로 원격 코드와 강제 동기화
- Jetson 환경에 맞는 미세 조정(비프음 끄기 등) 후 다시 `git push`로 동기화
- **교훈:** Jetson에서 임시 수정할 때는 `git stash`로 보관해두면 pull 충돌 없이 작업 가능. 가이드에 stash 워크플로우를 추가한 계기가 됨

### 8. sudo colcon build로 인한 권한 꼬임

- **상황:** Jetson Docker에서 `colcon build` 시 `PermissionError: [Errno 13] Permission denied: 'log/build_...'` 발생
- **원인:** 과거에 실수로 `sudo colcon build`를 실행하여 `build/`, `install/`, `log/` 폴더의 소유권이 root로 변경됨. 이후 일반 사용자로 빌드 시 쓰기 권한 없음
- **해결:**`bash cd ~/gae_ws sudo rm -rf build install log colcon build --packages-select gae_interface # sudo 없이! source install/setup.bash`
- **팀 공유:** "**colcon build에 절대 sudo 붙이지 마세요**"를 팀 전체에 공유. 한 번 꼬이면 전체 빌드 폴더를 날려야 하는 상황이 됨

---

## 관리자로서 한 일 요약

| 역할 | 상세 |
| --- | --- |
| **가이드 작성** | 15페이지 Git 컨벤션 문서 작성 및 배포 (2026.01.13) |
| **브랜치 전략** | main ← develop ← feature/* 구조 수립 |
| **커밋 규칙** | feat/fix/refactor/docs/style 접두사 체계 도입 |
| **PR 프로세스** | 양식 작성 + 전원 approve 후 머지 규칙 |
| **충돌 해결** | divergent branches, merge conflict 등 실시간 대응 |
| **팀원 지원** | 상황별 대응법, stash 워크플로우 등 추가 가이드 제공 |
| **환경 관리** | 3개 환경(Desktop/Jetson/Docker) 간 파일 동기화 워크플로우 수립 |

---

## 기술적 의사결정

### Q. 왜 Git 가이드를 직접 작성했나?

팀원 중 Git 사용이 익숙하지 않은 인원이 있었고, 프로젝트 초기에 브랜치 꼬임이나 충돌이 빈번하면 개발 속도가 크게 떨어집니다. 15페이지 분량의 가이드를 프로젝트 2일차에 배포하여, 이후 6주간 큰 Git 사고 없이 협업을 진행할 수 있었습니다.

### Q. 왜 pull 80% / rebase 20%인가?

rebase는 히스토리가 깔끔하지만 강제 푸시가 필요하고, 초보자에게 위험합니다. 대부분의 작업에서는 `git pull origin develop`으로 충분하고, PR 직전 히스토리 정리가 필요할 때만 rebase를 사용하도록 했습니다. 실무에서도 이 비율이 가장 일반적입니다.

### Q. 왜 main에 직접 작업을 금지했나?

main은 배포용 브랜치로, 직접 작업하다가 실수로 push하면 전체 서비스에 영향을 줍니다. develop을 통합 브랜치로 두고, feature 브랜치에서만 작업하여 코드 리뷰를 거치도록 했습니다.

### Q. PR에 전원 approve가 필요한 이유?

6인 팀에서 각자 담당 영역(웹, AI, 하드웨어)이 다르므로, 자신의 코드가 다른 영역에 영향을 주는지 확인하기 위해 전원 리뷰를 도입했습니다. 특히 공유 파일(connect.sh, Mosquitto 설정 등)의 수정은 반드시 팀원 확인이 필요했습니다.

### Q. 팀원에게 checkout 대신 switch를 쓰라고 한 이유?

`git checkout`은 브랜치 이동과 파일 복원을 하나의 명령어로 처리해서, `git checkout develop`이 "develop 브랜치로 이동"인지 "develop이라는 파일 복원"인지 헷갈리는 문제가 있었습니다. Git 2.23부터 `switch`(브랜치 이동)와 `restore`(파일 복원)로 분리됐기 때문에, 가이드 전체를 `switch` 기준으로 작성해서 팀원들이 처음부터 새 명령어에 익숙해지도록 했습니다. 실제로 팀원들이 "이게 브랜치 이동이야 파일 복원이야?" 하고 헷갈리는 상황이 사라졌습니다.