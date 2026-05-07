# 챗봇 앱 연동 계획서

> **작성일**: 2026-05-06  
> **선행 문서**: [phase_c_plan.md](phase_c_plan.md)  
> **현재 상태**: 백엔드 챗봇 API 구현 완료, EC2 배포 완료, 가드레일/히스토리/토큰 자동 갱신 검증 완료  
> **문서 목적**: 앱팀이 기존 인증/네트워크 구조 위에 챗봇 기능을 빠르게 연결할 수 있도록 작업 범위와 순서를 명확히 정의

---

## 0. 핵심 결론

- 지금 우선순위는 **챗봇 고도화보다 앱 연결**이다.
- 이유는 백엔드 API 계약이 이미 안정화됐고, 앱에 **Bearer 토큰 + 401 refresh 재시도 인터셉터**가 이미 있기 때문이다.
- 따라서 1차 목표는 **최소 채팅 화면 연결**이다.
- 스트리밍, 추천 품질 고도화, UI 폴리싱은 2차 이후로 미룬다.

---

## 1. 현재 준비 상태

### 1-1. 백엔드

이미 준비된 항목:

- `POST /api/v1/chat` — 메시지 전송, 답변 수신
- `GET /api/v1/chat/history` — 현재 사용자 대화 복원
- `DELETE /api/v1/chat` — 현재 사용자 대화 초기화
- 운동 지원 범위 가드레일 적용
  - 지원 운동: 푸시업, 사이드 레터럴 레이즈, 이두 컬
  - 예: `하체 운동 추천해줘` → 앱 미지원 안내 + 지원 운동 기준 대안 제시
- Redis 기반 히스토리 저장
- Gemini 실제 호출 검증 완료
- EC2에서 access token 만료 1분 테스트로 `401 -> /auth/refresh -> 원 요청 재시도 200` 흐름 확인 완료

### 1-2. 앱

이미 준비된 항목:

- `Dio` 기반 공통 API 클라이언트 존재
- `Authorization: Bearer <token>` 자동 주입
- 인증 실패 `401` 발생 시 자동 `refresh` 호출
- 새 access token으로 원 요청 자동 재시도
- 새 refresh token 저장 로직 존재
- `GoRouter` 기반 라우팅 구조 존재
- `Home / History / Stats / MyPage` 하단 탭 구조 존재

즉, 앱팀은 **새 인증 구조를 만들 필요가 없고**, 기존 `apiDio` 위에 채팅 API만 연결하면 된다.

---

## 2. 1차 목표 범위

### 목표

앱에서 다음 4가지만 되면 1차 연동 완료로 본다.

1. 홈에서 챗봇 화면 진입
2. 메시지 전송 후 답변 수신
3. 앱 재진입 시 이전 대화 복원
4. 대화 초기화 가능

### 제외 범위

이번 1차 범위에서 제외:

- 스트리밍 응답
- 음성 입력
- 추천 품질 추가 튜닝
- 챗봇 전용 하단 탭 추가
- 알림/푸시 연계
- 추천 결과 카드형 UI 고도화

---

## 3. 권장 연동 방식

### 3-1. 진입 위치

**권장안: `BottomNavShell` 우측 하단 플로팅 챗봇 버튼**

이유:

- 4개 탭(홈/기록/통계/마이) 어디서든 일관된 진입 가능 — 홈 카드는 홈에서만 가능.
- Siri / Google Assistant / 카카오톡 채널 등 검증된 챗봇 UX 패턴.
- 홈 화면 레이아웃 변경 없음 (`운동하기` / `재활하기` 카드 그대로).
- 운동 / 캘리브레이션 / 세션결과 등 `ShellRoute` 바깥 화면에선 자연스럽게 비노출 → 몰입 방해 방지.

권장 UX 스펙:

- 위치: 화면 우측 하단, 하단 탭(`AppSpacing.bottomNavHeight = 68`) 위 16dp / 우측 16dp.
  - `Scaffold.floatingActionButton` + `FloatingActionButtonLocation.endFloat` 사용 → Scaffold가 하단 탭 높이를 자동으로 인지해 띄워줌.
- 크기: 56dp 원형.
- 배경: `LinearGradient(topLeft → bottomRight, [AppColors.primary, AppColors.primaryStrong])` (홈 `_HomeActionCard` "운동하기" 카드와 동일 톤).
- 그림자: `primaryStrong.withValues(alpha: 0.3)`, blur 16, offset (0, 8).
- 1차 아이콘: `Icons.smart_toy_rounded` (흰색, 26dp).
- 2차 마스코트: 캐릭터 SVG / Lottie로 교체 가능 (위젯 한 곳만 수정).
- 탭 동작: `context.go('/chat')`.

### 3-2. 네트워크 방식

**기존 `apiDio` 그대로 사용**

이유:

- 챗봇 API도 일반 인증 REST API다.
- 별도 토큰 처리 로직을 만들 필요가 없다.
- 이미 검증된 refresh 재시도 구조를 재사용할 수 있다.

### 3-3. 데이터 흐름

```text
앱 ChatScreen 진입
  -> GET /api/v1/chat/history
  -> 이전 대화 목록 렌더링

사용자 메시지 입력
  -> POST /api/v1/chat { message }
  -> 응답 reply 수신
  -> 메시지 목록 갱신

대화 초기화 버튼
  -> DELETE /api/v1/chat
  -> 로컬 목록 비우기
```

---

## 4. 앱팀 작업 범위

> **아키텍처 컨벤션 (모든 신규/수정 파일이 따른다)**
>
> - **DI**: `get_it` (Repo는 `registerLazySingleton`, ViewModel은 `registerFactory`)
> - **상태관리**: `provider` + `ChangeNotifier`
> - **라우팅**: `go_router`
> - **디자인 토큰**: `AppColors`, `AppTextStyles`, `AppSpacing` (모두 `ui/core/themes/design_tokens.dart` re-export)
> - **공용 위젯**: `AppScaffold`, `ImoCard`, `ImoButton`, `ImoTextField`, `ImoChip`, `ImoConfirmDialog`
> - **API 응답 포맷**: `{success: bool, data: ..., error: ...}` — 기존 `ApiService` 패턴 그대로
> - **에러 처리**: `try { ... } on DioException catch (e) { throw Exception(_apiErrorMessage(e.response?.data, fallback)); }` 패턴 따름

### 4-1. 서비스 계층 — `ApiService` 챗봇 메서드 추가

**파일**: [`lib/data/services/api_service.dart`](../app/lib/data/services/api_service.dart) *(수정)*

기존 섹션 주석 컨벤션(`═══ 섹션명 ═══`)에 따라 새 섹션 추가:

```dart
// ═══════════════════════════════════════════════════════════
//  챗봇 (API-CHAT)
// ═══════════════════════════════════════════════════════════
```

추가 메서드 (모두 `_apiErrorMessage` 패턴 사용):

| 메서드 시그니처 | HTTP | 경로 | 응답 변환 |
|---|---|---|---|
| `Future<ChatSendResult> sendChatMessage(String message)` | POST | `/chat` | `data` → `ChatSendResult.fromJson` |
| `Future<List<ChatMessage>> getChatHistory()` | GET | `/chat/history` | `data['messages']` (List) → `List<ChatMessage>` |
| `Future<void> clearChatHistory()` | DELETE | `/chat` | 성공 여부만 검증 |

> 응답 → 도메인 모델 변환을 ApiService 내부에서 수행 (기존 `getProfile`, `getSessionDetail` 패턴과 동일).

### 4-2. 모델 계층 — 신규 2개

#### `lib/domain/models/chat_message.dart` *(신규)*

```dart
enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

파싱 규칙:

- `role` 파싱: `"user"` → `ChatRole.user`, 그 외(`"assistant"`, `"guardrail"`, 미지의 값) → `ChatRole.assistant`로 폴백
- `timestamp`: `DateTime.parse(json['timestamp'] as String)`. 누락 시 `DateTime.now()`.

#### `lib/domain/models/chat_send_result.dart` *(신규)*

```dart
class ChatSendResult {
  final String reply;
  final String model;     // "gemini-2.5-flash" | "guardrail" | ...
  final ChatTokenUsage? tokensUsed;

  const ChatSendResult({required this.reply, required this.model, this.tokensUsed});

  factory ChatSendResult.fromJson(Map<String, dynamic> json);
}

class ChatTokenUsage {
  final int input;
  final int output;
  final int cached;

  const ChatTokenUsage({required this.input, required this.output, required this.cached});

  factory ChatTokenUsage.fromJson(Map<String, dynamic> json);
}
```

> `model == "guardrail"` 응답도 일반 어시스턴트 메시지처럼 렌더 (분기 X — §6 가드레일 정책).

### 4-3. 레포지토리 계층

#### `lib/data/repositories/chat_repository.dart` *(신규)*

```dart
class ChatRepository {
  final ApiService _api;
  ChatRepository(this._api);

  Future<List<ChatMessage>> loadHistory() => _api.getChatHistory();

  Future<ChatMessage> send(String message) async {
    final result = await _api.sendChatMessage(message);
    return ChatMessage(
      role: ChatRole.assistant,
      content: result.reply,
      timestamp: DateTime.now(),
    );
  }

  Future<void> clear() => _api.clearChatHistory();
}
```

> `SessionHistoryRepository`와 동일한 단순 위임 + 도메인 변환 패턴. 향후 로컬 optimistic update / 재시도 정책은 이 계층에서 흡수.

### 4-4. ViewModel 계층

#### `lib/ui/chat/view_model/chat_viewmodel.dart` *(신규)*

```dart
class ChatViewModel extends ChangeNotifier {
  final ChatRepository _repo;
  ChatViewModel(this._repo);

  List<ChatMessage> messages = [];
  bool isInitializing = false;  // 초기 히스토리 로딩
  bool isSending = false;       // 메시지 전송 중 (응답 대기)
  String? errorMessage;          // SnackBar 트리거용. 소비 후 null로 리셋

  Future<void> loadHistory();
  Future<void> sendMessage(String text);
  Future<void> clearHistory();
}
```

상태 흐름:

- **`loadHistory()`** — 화면 진입 시 1회 호출.
  - `isInitializing = true` → `_repo.loadHistory()` → `messages` 갱신 → `isInitializing = false`.
  - 빈 응답이면 `messages = []` 유지 (UI에서 빈 상태 노출).
  - 실패 시 `errorMessage` 세팅.

- **`sendMessage(text)`** —
  1. 사용자 메시지 즉시 `messages`에 추가 (optimistic, `notifyListeners`).
  2. `isSending = true` → `_repo.send(text)` → 어시스턴트 메시지 추가 → `isSending = false`.
  3. 실패 시 `errorMessage` 세팅, 사용자 메시지는 유지(재전송 가능).
  4. `text.trim().isEmpty || isSending`이면 no-op.

- **`clearHistory()`** —
  - `_repo.clear()` 성공 시 `messages = []`. 실패 시 `errorMessage`.

### 4-5. UI 계층 — `ChatScreen`

#### `lib/ui/chat/widgets/chat_screen.dart` *(신규)*

화면 골격:

```dart
AppScaffold(
  title: 'AI 코치',
  showBackButton: true,
  actions: [_ClearAction()],   // 우측 휴지통 아이콘
  body: Column(
    children: [
      Expanded(child: _MessageList()),   // 자동 스크롤 ListView
      _InputBar(),                        // 하단 고정
    ],
  ),
)
```

**메시지 버블 (`_ChatBubble`)**

| 종류 | 정렬 | 배경 | 텍스트 | 아이콘 |
|---|---|---|---|---|
| 사용자 (`role == user`) | 오른쪽 | `AppColors.primary` | `AppColors.card` | 없음 |
| 어시스턴트 (`role == assistant`) | 왼쪽 | `AppColors.cardSubtle` | `AppColors.textPrimary` | 좌측 `Icons.smart_toy_rounded` 16dp, `primary` |

- max width: 화면의 75%.
- padding: `EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm)`.
- radius: `AppSpacing.cardRadius` (20).
- 메시지 사이 간격: `AppSpacing.sm` (12).
- 마크다운 렌더 안 함 — 1차는 `Text` 위젯만 (`AppTextStyles.body`).

**빈 상태 (히스토리 없을 때)**

- `messages.isEmpty && !isInitializing && !isSending`이면:
  - 어시스턴트 인사 버블 1개 — `안녕하세요! 운동 추천을 도와드릴게요.`
  - 그 아래 `Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs)` 안에 `ImoChip` 3개:
    - `어깨 운동 추천해줘`
    - `푸시업 폼 알려줘`
    - `오늘 루틴 짜줘`
  - 칩 `onTap` → 해당 텍스트로 `viewModel.sendMessage(...)` 호출.

**로딩 상태 (`_TypingIndicator`)**

- `isSending == true`일 때 메시지 리스트 끝에 어시스턴트 버블 자리 표시.
- 점 3개 페이드 애니메이션 (`AnimationController` + `AnimatedBuilder`).
- 초기 로딩 (`isInitializing`)은 화면 가운데 `CircularProgressIndicator`.

**입력 바 (`_InputBar`)**

- `Container(decoration: BoxDecoration(color: AppColors.card, border: Border(top: BorderSide(color: AppColors.border))))` 로 상단 보더 분리.
- `SafeArea(top: false)` + `padding: AppSpacing.md`.
- `Row` 안에 `ImoTextField`(Expanded, `clearable: true`, `hint: '메시지를 입력하세요...'`) + `SizedBox(width: AppSpacing.sm)` + 전송 버튼.
- 전송 버튼: `IconButton`(`Icons.send_rounded`, `AppColors.primary`).
- 비활성 조건: 입력 trim이 빈 문자열 OR `isSending == true`.
- Enter 키 (`onSubmitted`) / 전송 버튼 둘 다 동일 핸들러.

**초기화 다이얼로그**

- AppBar `actions`의 휴지통 `IconButton(Icons.delete_outline_rounded)` 탭 →
  ```dart
  showDialog(
    context: context,
    builder: (_) => ImoConfirmDialog(
      title: '대화 초기화',
      message: '대화 내용을 모두 삭제할까요?',
      confirmLabel: '삭제',
      danger: true,
      onConfirm: () { Navigator.pop(context); viewModel.clearHistory(); },
    ),
  );
  ```

**에러 표시**

- `viewModel`을 `Consumer`로 구독하면서 `errorMessage` 변경 시 `addPostFrameCallback`으로 `ScaffoldMessenger.of(context).showSnackBar(...)`.
- SnackBar 노출 후 ViewModel의 `errorMessage = null`로 소비 처리(중복 노출 방지).

**자동 스크롤**

- `_MessageListState`가 `ScrollController` 보유.
- `messages.length` 변하거나 `isSending` 토글될 때 `addPostFrameCallback`으로 `controller.animateTo(maxScrollExtent, duration: 200ms, curve: easeOut)`.

### 4-6. 진입 버튼 — `BottomNavShell` 플로팅 버튼

**파일**: [`lib/ui/core/layouts/bottom_nav_shell.dart`](../app/lib/ui/core/layouts/bottom_nav_shell.dart) *(수정)*

`Scaffold`에 `floatingActionButton` 슬롯 추가:

```dart
return Scaffold(
  extendBody: true,
  backgroundColor: AppColors.background,
  body: child,
  bottomNavigationBar: _BlurBottomNavigationBar(...),
  floatingActionButton: const _ChatbotFab(),
  floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
);
```

`_ChatbotFab` (같은 파일 내 private 위젯, §3-1 스펙대로):

- 56dp 원형, `Material(shape: CircleBorder, color: Colors.transparent)` + `Ink(BoxDecoration(shape: circle, gradient, boxShadow))` + `InkWell(customBorder: CircleBorder, onTap: () => context.go('/chat'))`.
- 그라디언트: `LinearGradient(begin: topLeft, end: bottomRight, colors: [AppColors.primary, AppColors.primaryStrong])`.
- 그림자: `BoxShadow(color: AppColors.primaryStrong.withValues(alpha: 0.3), blurRadius: 16, offset: Offset(0, 8))`.
- 자식: `Icon(Icons.smart_toy_rounded, color: Colors.white, size: 26)`.

> Scaffold가 `bottomNavigationBar` 높이를 자동 인지 → FAB가 하단 탭 위에 떠 있다. `extendBody: true`라도 endFloat 위치는 안전.

### 4-7. 라우팅 — `/chat`

**파일**: [`lib/config/router.dart`](../app/lib/config/router.dart) *(수정)*

- `ShellRoute` **바깥**에 추가 (하단 탭 비노출, 챗봇 진입 시 풀스크린).
- 진입 시 `loadHistory()` 자동 호출.

```dart
GoRoute(
  path: '/chat',
  builder: (context, state) => ChangeNotifierProvider(
    create: (_) => getIt<ChatViewModel>()..loadHistory(),
    child: const ChatScreen(),
  ),
),
```

> import 추가:
> - `import '../ui/chat/view_model/chat_viewmodel.dart';`
> - `import '../ui/chat/widgets/chat_screen.dart';`

### 4-8. DI 등록 — `dependencies.dart`

**파일**: [`lib/config/dependencies.dart`](../app/lib/config/dependencies.dart) *(수정)*

`setupDependencies()` 함수 안, 기존 Repository 등록 블록 다음에 추가:

```dart
getIt.registerLazySingleton(
  () => ChatRepository(getIt<ApiService>()),
);
getIt.registerFactory(
  () => ChatViewModel(getIt<ChatRepository>()),
);
```

import 추가:

```dart
import '../data/repositories/chat_repository.dart';
import '../ui/chat/view_model/chat_viewmodel.dart';
```

### 4-9. 변경 파일 요약

#### 신규 (5개)

| 경로 | 책임 |
|---|---|
| `lib/domain/models/chat_message.dart` | `ChatRole` enum + `ChatMessage` 모델 (role/content/timestamp) |
| `lib/domain/models/chat_send_result.dart` | `ChatSendResult` + `ChatTokenUsage` |
| `lib/data/repositories/chat_repository.dart` | API → 도메인 변환, `loadHistory` / `send` / `clear` |
| `lib/ui/chat/view_model/chat_viewmodel.dart` | 상태(`messages` / `isInitializing` / `isSending` / `errorMessage`) |
| `lib/ui/chat/widgets/chat_screen.dart` | `ChatScreen` + private(`_MessageList` / `_ChatBubble` / `_TypingIndicator` / `_InputBar` / `_ClearAction`) |

#### 수정 (4개)

| 파일 | 변경 |
|---|---|
| `lib/data/services/api_service.dart` | 챗봇 섹션 + `sendChatMessage` / `getChatHistory` / `clearChatHistory` 3개 |
| `lib/config/dependencies.dart` | `ChatRepository` (LazySingleton) + `ChatViewModel` (Factory) 등록 |
| `lib/config/router.dart` | `/chat` 라우트 (`ShellRoute` 바깥, `ChangeNotifierProvider` 주입) |
| `lib/ui/core/layouts/bottom_nav_shell.dart` | `_ChatbotFab` private 위젯 + `Scaffold.floatingActionButton` 슬롯 |

> **건드리지 않는 파일**: `apiDio` 인터셉터 / `home_screen.dart` / `bottom_nav_shell.dart`의 `_BlurBottomNavigationBar` 내부 / 기존 라우트.

### 4-10. 폴더 구조 (변경 후)

```
lib/
├── config/
│   ├── dependencies.dart          ← 수정 (Chat Repo/VM 등록)
│   └── router.dart                ← 수정 (/chat 라우트)
├── data/
│   ├── repositories/
│   │   └── chat_repository.dart   ← 신규
│   └── services/
│       └── api_service.dart       ← 수정 (챗봇 섹션 + 3개 메서드)
├── domain/
│   └── models/
│       ├── chat_message.dart      ← 신규
│       └── chat_send_result.dart  ← 신규
└── ui/
    ├── chat/                       ← 신규 폴더
    │   ├── view_model/
    │   │   └── chat_viewmodel.dart  ← 신규
    │   └── widgets/
    │       └── chat_screen.dart     ← 신규
    └── core/
        └── layouts/
            └── bottom_nav_shell.dart  ← 수정 (FAB 추가)
```

---

## 5. API 계약 요약

### 5-1. POST `/api/v1/chat`

요청:

```json
{ "message": "어깨 운동 추천해줘" }
```

응답:

```json
{
  "success": true,
  "data": {
    "reply": "IMO 앱에서는 어깨 운동으로 사이드 레터럴 레이즈를 지원합니다.",
    "model": "gemini-2.5-flash",
    "tokensUsed": { "input": 335, "output": 40, "cached": 0 }
  },
  "error": null
}
```

### 5-2. GET `/api/v1/chat/history`

응답:

```json
{
  "success": true,
  "data": {
    "messages": [
      {
        "role": "user",
        "content": "어깨 운동 추천해줘",
        "timestamp": "2026-05-06T07:13:42.617920+00:00"
      },
      {
        "role": "assistant",
        "content": "IMO 앱에서는 어깨 운동으로 사이드 레터럴 레이즈를 지원합니다.",
        "timestamp": "2026-05-06T07:13:42.617920+00:00"
      }
    ]
  },
  "error": null
}
```

### 5-3. DELETE `/api/v1/chat`

응답:

```json
{
  "success": true,
  "data": { "cleared": true },
  "error": null
}
```

---

## 6. 가드레일 반영 방식

앱은 가드레일을 별도 구현하지 않는다.

이유:

- 정책은 백엔드가 단일 책임으로 관리해야 한다.
- 앱이 따로 문구 분기하면 정책 불일치가 생긴다.
- 현재 백엔드는 미지원 운동 요청 시 `model: "guardrail"` 로 응답한다.

앱 처리 원칙:

- `reply` 를 일반 메시지처럼 그대로 렌더링
- `model` 값은 1차에서는 숨겨도 무방
- 필요 시 디버그 모드에서만 표시

---

## 7. 검증 시나리오

### 7-1. 기본 기능

1. 로그인 후 챗봇 화면 진입
2. `어깨 운동 추천해줘` 전송
3. 답변 수신 확인
4. `하체 운동 추천해줘` 전송
5. 앱 미지원 안내 문구 확인
6. `그럼 지금 앱에서 할 수 있는 운동 루틴 추천해줘` 전송
7. 이전 문맥을 반영한 답변 확인

### 7-2. 복원 기능

1. 대화 2~3턴 진행
2. 화면 이탈
3. 다시 진입
4. 이전 메시지 복원 확인

### 7-3. 초기화 기능

1. 대화 진행
2. 초기화 버튼 클릭
3. 메시지 목록 비워짐 확인
4. 재진입 후에도 비어 있는지 확인

### 7-4. 인증 자동 갱신

이미 서버 측 1분 만료 테스트로 검증 완료했지만, 앱 연동 후 다시 확인:

1. 로그인
2. 챗봇 화면 진입
3. 1분 이상 대기
4. 메시지 전송 또는 히스토리 재조회
5. 내부적으로 `401 -> /auth/refresh -> 원 요청 재시도 200` 확인

---

## 8. 작업 순서 제안

> 각 Step은 독립 커밋 단위로 끊어 갈 수 있게 정리. §4의 파일 설계를 그대로 따른다.

### Step 1. 모델 + 서비스

- `ChatMessage`, `ChatSendResult` 모델 (§4-2)
- `ApiService` 에 챗봇 섹션 + 3개 메서드 (§4-1)

### Step 2. 레포지토리 + ViewModel + DI

- `ChatRepository` (§4-3)
- `ChatViewModel` (§4-4)
- `dependencies.dart` 에 `ChatRepository` (LazySingleton) + `ChatViewModel` (Factory) 등록 (§4-8)

### Step 3. 라우트

- `router.dart` 에 `/chat` 라우트 추가 (`ShellRoute` 바깥, `ChangeNotifierProvider`로 ViewModel 주입) (§4-7)

### Step 4. 챗 화면 UI

- `ChatScreen` + private 위젯들(`_MessageList` / `_ChatBubble` / `_TypingIndicator` / `_InputBar` / `_ClearAction`) (§4-5)
- 빈 상태 / 로딩 / 초기화 다이얼로그 / SnackBar / 자동 스크롤 모두 포함

### Step 5. 진입 버튼

- `BottomNavShell` 에 `_ChatbotFab` 추가 + `Scaffold.floatingActionButton` 슬롯 연결 (§4-6)

### Step 6. 기능 검증

§7 시나리오 4종:

- 기본 질의 (가드레일 포함)
- 히스토리 복원
- 초기화
- 토큰 refresh (1분 만료 테스트)

---

## 9. 역할 분담 제안

### 백엔드

- 현재 API 유지
- 앱 연동 중 발견되는 응답 포맷 이슈 수정
- 필요 시 추가 테스트 계정/데모 데이터 제공

### 앱팀

- 채팅 화면 및 라우트 구현
- API 연동
- 상태 관리
- UX 최소 완성

---

## 10. 2차 고도화 후보

앱 연결 이후 검토:

- 스트리밍 응답(SSE 또는 WebSocket)
- **챗봇 FAB 캐릭터 마스코트 교체** (Lottie 또는 SVG) — `_ChatbotFab` 위젯 한 곳만 수정
- **챗봇 FAB 신규 메시지 뱃지(Badge) 표시** — `Stack` + 우상단 빨간 점
- 추천 결과 카드형 UI
- 운동별 빠른 질문 버튼 확장
- 응답 내 운동 이미지/가이드 링크 연결
- 마크다운 렌더링 (`flutter_markdown`)
- 대화방 진입점 하단 탭 승격
- 토큰 사용량 디버그 표시 (`ChatSendResult.tokensUsed` 활용)
- 사용자 목표/최근 세션 기반 프롬프트 추가 고도화

---

## 11. 최종 권장안

**이번 스프린트 목표는 “완성도 높은 AI 챗 UI”가 아니라 “앱에서 실제로 쓰이는 챗봇 연결”이다.**

따라서 가장 합리적인 1차 목표는 아래다.

- 4개 탭(홈/기록/통계/마이) 어디서든 플로팅 버튼으로 챗봇 화면 진입
- 기존 인증 구조 위에 chat API 연결
- 멀티턴 대화 / 히스토리 복원 / 초기화까지 구현
- 미지원 운동은 백엔드 가드레일 문구 그대로 노출

이 범위를 먼저 완료한 뒤, 사용성 피드백을 보고 2차 고도화로 넘어간다.
