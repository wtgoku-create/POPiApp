# Web and native app adaptation

Use `lib/core/platform/app_platform.dart` for runtime capabilities:

```dart
final platform = AppPlatform.current;
if (platform.isWeb) {
  // Browser APIs, including browsers on phones.
} else if (platform.isNativeMobile) {
  // Native Android/iOS APIs, including tablets.
} else if (platform.isNativeDesktop) {
  // Native macOS/Windows/Linux APIs.
}
```

`targetPlatform` exposes Flutter's `TargetPlatform` for OS-specific behavior.
On Web it is a UI platform hint, not proof of the physical device or plugin
availability. Check plugin support before using platform APIs.

Web and mobile apps share the same application code and entry point. Use
`isWeb` to choose browser behavior and `isNativeMobile` for installed Android/iOS
app behavior. These checks do not depend on screen width: a mobile browser is
Web, and a tablet running the installed app is a native mobile app. Keep
responsive layout decisions based on the space available to the widget.

Development/production service configuration remains in
`AppConfig.environment` and `config/env/*.json`, separate from runtime platform.

## Modal presentation

On Web, `AppDialog` and `AppSheet` always use the root Navigator, including
calls that request a local Navigator. Their backdrop covers the full window;
switching panes or removing the source page does not dismiss them. Close them
using the builder's dialog/sheet context so their result returns to the caller.
`AppMenuButton` and `AppContextMenu` also use the root overlay/Navigator, while
remaining anchored to their source widget. Native app presentation and pane
lifecycle behavior are unchanged.

Regression checks:

```bash
flutter test test/app_platform_test.dart
```
