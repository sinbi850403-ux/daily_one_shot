# 네이티브 홈 위젯 구현 가이드

Flutter `home_widget` 패키지는 데이터 브리지만 제공합니다. 실제 홈 화면 위젯은
플랫폼별 네이티브 코드로 만들어야 합니다. 이 문서는 그 다음 단계입니다.

## iOS (WidgetKit)

1. Xcode에서 프로젝트 열기: `open ios/Runner.xcworkspace`
2. File → New → Target → **Widget Extension**, 이름 `DailyOneShotWidget`
3. App Group 활성화 (Runner + Widget extension 양쪽에 동일한 group ID)
4. `HomeWidget.setAppGroupId('group.com.dailyoneshot.shared')`를 Flutter 부트에서 호출
5. Widget 스위프트 코드에서 `UserDefaults(suiteName: "group.com.dailyoneshot.shared")` 로 다음 키 읽기:
   - `today_has_entry` (Bool)
   - `today_thumb_path` (String 경로)
   - `memory_memo` (String)
   - `memory_thumb_path` (String)
   - `memory_years_ago` (Int)

## Android (Glance / RemoteViews)

1. `android/app/src/main/kotlin/.../` 아래에 `DailyOneShotWidgetProvider.kt` 생성
   (`AppWidgetProvider` 상속)
2. `home_widget` 문서 예제 그대로 사용: `HomeWidgetPlugin.getData(context)` 로
   위 키들 읽기
3. `res/xml/daily_one_shot_widget_info.xml` 에 위젯 메타데이터
4. `AndroidManifest.xml` 에 receiver 등록

## 주의

- 썸네일 경로는 **앱 샌드박스 내부**입니다. iOS는 App Group으로 공유해야 위젯이
  파일을 읽을 수 있습니다. Android는 `getFilesDir()` 영역이라 같은 프로세스에서
  접근 가능합니다.
- 위젯 사진은 256px로 미리 캐시됨 (Glance OOM 회피)
