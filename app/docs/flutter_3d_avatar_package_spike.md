# [APP][Spike] Flutter 3D Avatar Package 검토

## 0. 작업 기준

- 기준 프로젝트: `C:\Users\SSAFY\Desktop\C203\S14P31C203`
- 작성일: 2026-05-08
- 기준 문서:
  - `docs/avatar_project_audit_report.md`
  - `app/docs/avatar_2d_to_3d_scope.md`
- 이번 작업은 문서 spike다.
- 앱 코드, `pubspec.yaml`, Android/iOS 설정은 수정하지 않는다.

## 1. 실제 프로젝트 기준 결론

현재 앱의 MVP는 `HeatmapTab`의 2D 전면/후면 근육 히트맵이다. 3D는 제품 필수 기능이 아니라 Android 시연 기준 optional spike로만 검토한다.

3D 패키지 선정에서 가장 중요한 기준은 단순히 GLB를 띄우는 것이 아니라, 앱의 `muscle_map` key를 3D 모델 내부 mesh/entity id에 연결해 부위별 색상을 바꿀 수 있는지다.

최종 판단:

| 용도 | 후보 |
| --- | --- |
| 단순 3D 모델 표시 | `model_viewer_plus` |
| 회전/카메라 제어 | `flutter_3d_controller`, 보조로 `o3d` |
| 근육 mesh/entity 색상 변경 spike | `interactive_3d` |
| Android-only 실험 | `playx_3d_scene` |
| 제품 코드 바로 투입 보류 | 전체 후보. 특히 `playx_3d_scene`, `flutter_scene` |

권장 진행:

1. MVP는 2D fallback으로 유지한다.
2. Android spike는 `interactive_3d`로 "부위 이름 기반 색상 patch"가 실제 인체 GLB에서 되는지 먼저 검증한다.
3. 단순 회전 가능한 3D 미리보기만 필요하면 `flutter_3d_controller`를 비교 대상으로 둔다.
4. `model_viewer_plus`는 가장 쉬운 표시 후보지만, 근육별 색상 변경 요구에는 약하다.

## 2. 프로젝트 현재 상태

현재 `app/pubspec.yaml`에는 3D 패키지가 없다.

현재 Android 설정:

- `app/android/app/build.gradle.kts`는 `minSdk = flutter.minSdkVersion`, `ndkVersion = flutter.ndkVersion`를 사용한다.
- `app/android/app/src/main/AndroidManifest.xml`에는 `INTERNET` permission이 있다.
- `usesCleartextTraffic`, iOS embedded views preview, 패키지별 NDK 고정 등은 아직 없다.

따라서 WebView 기반 패키지나 native renderer 패키지를 넣으려면 별도 플랫폼 설정 변경이 필요할 수 있다. 이번 작업에서는 변경하지 않는다.

## 3. 패키지 비교표

| 패키지 | Android | iOS | GLB/GLTF 로컬 asset | 회전/카메라 | 부위별 색상 변경 | 렌더링 기반 | HeatmapTab 적합성 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `model_viewer_plus` | 지원 | 지원 | 지원 | 기본 상호작용/auto rotate | 낮음 | WebView + `<model-viewer>` | 단순 표시만 적합 |
| `flutter_3d_controller` | 지원 | 지원 | 지원 | 좋음. controller 제공 | 낮음~중간. texture 전환 중심 | WebView 계열 | 회전 데모 적합 |
| `interactive_3d` | 지원 | 지원 | 지원 | 회전/팬/탭 | 높음. entity name 기반 color patch | Android Filament, iOS GLTFSceneKit | mesh 색상 spike에 가장 적합 |
| `playx_3d_scene` | 지원 | 미지원 | 지원 | 좋음. orbit/free camera | 중간. native material 가능성은 있으나 앱 API 확인 필요 | Android Filament | Android-only 실험용 |
| `flutter_scene` | 지원 | 지원 | GLB asset import | 가능성 있음 | 가능성은 있으나 직접 구현 부담 큼 | Flutter GPU/Impeller | 현재 제품에는 이르다 |
| `o3d` | 지원 | 지원 | 지원 | 좋음. camera target/orbit controller | 낮음 | WebView + `<model-viewer>` | 보조 회전 데모용 |

## 4. 후보별 검토

### 4.1 `model_viewer_plus`

pub.dev 기준:

- 최신 확인 버전: `1.10.0`
- 플랫폼: Android, iOS, Web
- glTF/GLB 렌더링 지원
- WebView 안에 Google `<model-viewer>` web component를 띄우는 구조
- 로컬 asset GLB 로딩 가능
- Android는 localhost cleartext 설정과 `minSdkVersion 24`가 필요하다고 안내한다.
- iOS는 embedded views preview 설정이 필요하다.

프로젝트 기준 장점:

- 단순 3D 모델 표시가 가장 쉽다.
- `HeatmapTab` 안에 "3D 보기"를 붙이는 실험은 빠르게 가능하다.
- 2D fallback과 공존시키기 쉽다.

프로젝트 기준 단점:

- WebView 기반이라 native Flutter 위젯과 제스처/스크롤 충돌을 검증해야 한다.
- mesh/entity 단위 색상 변경은 공식 Flutter API 수준에서 명확하지 않다.
- `muscle_map.left_chest -> mesh.muscle.left_chest` 같은 동적 색상 patch에는 부적합하다.

판정:

- 단순 3D 모델 표시 후보.
- 근육별 히트맵 색상 후보로는 보류.

### 4.2 `flutter_3d_controller`

pub.dev 기준:

- 최신 확인 버전: `2.3.0`
- 플랫폼: Android, iOS, Web, macOS beta
- GLB/GLTF/OBJ 지원
- asset, URL 로딩 지원
- controller로 rotation, camera target, camera orbit, animation, texture를 제어한다.
- dependency에 `flutter_inappwebview`가 포함되어 WebView 계열 리스크가 있다.
- Android는 `minSdkVersion 21`, cleartext 설정 등을 안내한다.
- iOS는 embedded views preview 설정이 필요하다.

프로젝트 기준 장점:

- 회전/카메라 제어 API가 명확하다.
- 사용자가 3D 아바타를 회전하는 요구사항에는 잘 맞는다.
- 단순 viewer보다 interaction demo가 만들기 쉽다.

프로젝트 기준 단점:

- mesh별 material color patch보다는 texture/animation/controller 중심이다.
- 근육별 색상 변경을 하려면 상태별 texture를 미리 굽거나, WebView 내부 script 제어 가능성을 별도 검증해야 한다.
- WebView 계열이므로 `HeatmapTab` 스크롤, Android/iOS platform view, iOS gesture를 반드시 확인해야 한다.

판정:

- 회전/카메라 제어 후보.
- 근육 mesh/entity 색상 변경 주력 후보는 아님.

### 4.3 `interactive_3d`

pub.dev 기준:

- 최신 확인 버전: `2.0.4`
- 플랫폼: Android, iOS
- Android는 Filament, iOS는 GLTFSceneKit 사용
- GLB/GLTF asset 및 network 로딩 지원
- rotate, pan, tap interaction 지원
- entity name 기반 선택, preselect, color 변경, visibility 변경을 지원한다.
- `patchColors`로 이름 기반 색상 지정 예시가 있다.

프로젝트 기준 장점:

- 후보 중 `muscle_map` key와 mesh/entity id 매핑 요구에 가장 직접적으로 맞다.
- `left_chest`, `right_biceps` 같은 key를 GLB 내부 entity name과 맞추면 색상 patch spike가 가능하다.
- 의료/인체 부위 선택 문제를 염두에 둔 패키지라 아바타 요구와 방향이 가깝다.
- WebView가 아니라 native renderer 계열이라 mesh 조작 가능성이 상대적으로 높다.

프로젝트 기준 단점:

- 패키지가 비교적 젊고 사용량이 작다.
- Android Filament, iOS SceneKit 양쪽 빌드와 asset 호환성을 실제 기기에서 확인해야 한다.
- IBL/skybox `.ktx` 등 렌더링 자산 관리가 추가될 수 있다.
- 2D fallback 없이 바로 제품 코드에 넣기에는 리스크가 있다.

판정:

- 근육 mesh/entity 색상 변경 spike 1순위.
- Android 시연용으로 우선 검증하되, 제품 투입은 빌드/성능/asset 검증 후 결정.

### 4.4 `playx_3d_scene`

pub.dev 기준:

- 최신 확인 버전: `0.1.0`
- 플랫폼: Android only
- Android Filament 기반 native renderer
- GLB/GLTF asset 및 URL 로딩 지원
- orbit/free camera, light, skybox, ground, material 등 scene 제어 기능 제공
- Android `ndkVersion "26.1.10909125"` 및 shrink/minify 관련 설정 변경을 요구한다.

프로젝트 기준 장점:

- Android Filament 기반이라 시연 품질과 카메라 제어 가능성은 좋다.
- Android-only spike에서 scene/camera/material 제어 실험을 하기 좋다.

프로젝트 기준 단점:

- iOS 미지원이라 제품 구조에 바로 넣을 수 없다.
- 현재 앱은 2D fallback + optional 3D 구조가 필요하므로 Android 전용 의존성을 제품 path에 두면 분기 부담이 커진다.
- 마지막 publish 시점과 사용량 기준 유지보수 리스크가 있다.
- NDK/build 설정 변경 요구가 있어 이번 단계와 맞지 않는다.

판정:

- Android-only 시연 실험 후보.
- 제품 코드 후보로는 비추천.

### 4.5 `flutter_scene`

pub.dev 기준:

- 최신 확인 버전: `0.9.2-0`
- 플랫폼: Android, iOS, Linux, macOS, Windows
- GLB asset import 지원
- Flutter GPU/Impeller 기반의 3D rendering library
- early preview 상태이며, Flutter GPU/Native Assets 같은 preview 기능에 의존한다.
- 문서상 master channel 사용 권장 사항이 있다.

프로젝트 기준 장점:

- 장기적으로 Flutter-native 3D 방향과 잘 맞을 가능성은 있다.
- WebView가 아니라 렌더링 제어 가능성은 높다.

프로젝트 기준 단점:

- 현재 제품 앱에 넣기에는 너무 이르다.
- 빌드/채널/Native Assets 리스크가 크다.
- 빠른 Android spike나 MVP fallback 구조에는 과하다.

판정:

- 보조 후보로만 기록.
- 현재 제품 코드에 바로 넣으면 위험하다.

### 4.6 `o3d`

pub.dev 기준:

- 최신 확인 버전: `3.1.3`
- 플랫폼: Android, iOS, Web
- glTF/GLB 렌더링 지원
- WebView 안에 Google `<model-viewer>`를 띄우는 구조
- controller로 camera target/orbit, animation 등을 제어한다.

프로젝트 기준 장점:

- `model_viewer_plus`보다 controller API가 명확하다.
- 단순 회전/카메라 데모에 쓸 수 있다.

프로젝트 기준 단점:

- WebView 기반이다.
- 근육 mesh별 동적 색상 변경에는 약하다.
- 3D avatar 핵심 요구인 `muscle_map` key -> mesh color patch 검증에는 주력 후보가 아니다.

판정:

- 보조 회전 데모 후보.
- `flutter_3d_controller`와 역할이 겹치므로 우선순위는 낮다.

## 5. 목적별 추천

### 단순 3D 모델 표시 후보

1순위: `model_viewer_plus`

이유:

- GLB/GLTF asset 표시가 단순하다.
- Android/iOS/Web 지원 범위가 넓다.
- 2D fallback 뒤에 optional viewer로 붙이기 쉽다.

주의:

- mesh별 색상 변경 요구에는 맞지 않는다.
- 제품 히트맵 후보가 아니라 "모델 보여주기" 후보로만 본다.

### 회전/카메라 제어 후보

1순위: `flutter_3d_controller`

이유:

- camera orbit/target, rotation, touch enable 제어가 명확하다.
- 사용자가 아바타를 회전하는 요구사항 검증에 좋다.

보조: `o3d`

이유:

- controller가 있고 단순 camera demo가 가능하다.
- 다만 역할이 겹치므로 우선순위는 낮다.

### 근육 mesh/entity 색상 변경 후보

1순위: `interactive_3d`

이유:

- entity name 기반 선택/색상 변경/visibility 변경을 직접 지원한다.
- `muscle_map` stable key를 3D mesh/entity id에 연결하는 요구와 가장 가깝다.

검증 방식:

- 테스트 GLB의 mesh 이름을 `left_chest`, `right_chest` 등으로 분리한다.
- `patchColors`로 각 부위 색상을 다르게 지정한다.
- Android 기기에서 로딩, 회전, tap, 색상 변경을 확인한다.

### Android-only 실험 후보

후보: `playx_3d_scene`

이유:

- Android Filament 기반이고 scene/camera 기능이 많다.

제한:

- iOS 미지원.
- 제품 코드 후보로는 비추천.

### 제품 코드에 바로 넣으면 위험한 후보

| 후보 | 이유 |
| --- | --- |
| `interactive_3d` | mesh 색상 요구에는 맞지만, 패키지 성숙도와 native 빌드 검증 전 제품 투입은 위험 |
| `playx_3d_scene` | Android only |
| `flutter_scene` | early preview, Flutter GPU/Native Assets 리스크 |
| `model_viewer_plus` | 단순 표시용으로는 가능하지만 근육별 색상 요구를 충족하지 못할 가능성 큼 |
| `flutter_3d_controller` | 회전/카메라는 좋지만 mesh별 색상 patch 검증 필요 |

## 6. 실제 구현 전 검증해야 할 항목

3D 구현 전 필수 검증:

1. Android 실제 기기에서 GLB asset 로딩이 되는지 확인한다.
2. `HeatmapTab` 스크롤 안에서 platform view/WebView/native view가 제스처 충돌 없이 동작하는지 확인한다.
3. 테스트 GLB의 mesh/entity 이름을 `muscle_map` key와 맞췄을 때 색상 변경이 되는지 확인한다.
4. `left_chest`, `right_chest`, `left_biceps` 등 여러 부위를 동시에 색상 patch할 수 있는지 확인한다.
5. No data 부위를 회색으로 유지하고, 측정된 부위만 색상 적용할 수 있는지 확인한다.
6. `trunk`를 근육 mesh가 아니라 posture indicator로 분리할 수 있는지 확인한다.
7. 2D fallback을 끄지 않고 3D renderer만 optional로 켜고 끌 수 있는지 확인한다.
8. Android build 설정 변경이 기존 앱 빌드에 영향을 주지 않는지 별도 spike 브랜치에서 확인한다.
9. iOS는 MVP 범위 밖이지만, 제품화 전에는 최소 빌드 가능 여부를 확인한다.

## 7. 최종 추천

최종 추천은 다음과 같다.

| 분류 | 패키지 | 판단 |
| --- | --- | --- |
| 당장 Android spike 1순위 | `interactive_3d` | 근육 mesh/entity 색상 변경 검증에 가장 적합 |
| 회전/카메라 비교 후보 | `flutter_3d_controller` | 사용자 회전/카메라 UX 검증에 적합 |
| 단순 표시 후보 | `model_viewer_plus` | 쉬운 표시용. 히트맵 색상 요구에는 약함 |
| Android-only 실험 | `playx_3d_scene` | 시연 실험은 가능. 제품 후보는 아님 |
| 보류 | `flutter_scene` | 미래 가능성은 있으나 현재 preview 리스크 큼 |
| 보조 후보 | `o3d` | controller 있는 WebView viewer. 우선순위 낮음 |

제품 구조 결론:

- MVP는 2D 전면/후면 근육 히트맵이다.
- 3D는 `HeatmapTab` 안에 직접 섞기보다 optional renderer로 분리한다.
- 2D와 3D는 같은 `muscle_map` stable key 입력 계약을 공유한다.
- 3D가 실패하거나 미지원 플랫폼이면 항상 2D fallback이 표시되어야 한다.

## 8. 참고한 pub.dev 페이지

- `model_viewer_plus`: https://pub.dev/packages/model_viewer_plus
- `flutter_3d_controller`: https://pub.dev/packages/flutter_3d_controller
- `interactive_3d`: https://pub.dev/packages/interactive_3d
- `playx_3d_scene`: https://pub.dev/packages/playx_3d_scene
- `flutter_scene`: https://pub.dev/packages/flutter_scene
- `o3d`: https://pub.dev/packages/o3d

