# Web and native modal presentation

Use `AppPlatform.current` from `lib/core/platform/app_platform.dart` to distinguish
Web from installed applications. Mobile browsers use Web presentation regardless
of viewport width.

`AppSheet.show` presents a centered dialog on Web, using the shared `AppDialog`
route, backdrop and transitions. Dialogs have an opaque surface, 26px corners,
no drag handle, a maximum width of 480px and a maximum height of 80% of the
window. Short contents retain their natural height. Keyboard insets and narrow
windows further constrain the dialog. Draggable sheet contents use a regular
scroll controller on Web; installed apps retain their original resizing and
bottom sheet gestures.

Regression checks:

```bash
flutter test test/app_sheet_test.dart test/app_dialog_test.dart
flutter test --platform chrome test/app_sheet_web_test.dart
```
