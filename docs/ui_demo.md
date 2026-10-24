# POPi UI Mock Demo

This entry point implements the creation flows from Figma section `2056:3269` with local mock data. The avatar opens the existing production profile and account pages, which retain their normal backend behavior and signed-in account.

## Run on a phone

```bash
flutter pub get
flutter devices
dart run tool/flutter_env.dart development run --profile -t lib/main_demo.dart -d <device-id>
```

For a simulator, omit `--profile`. Profile mode can run independently on a phone and uses this project's existing development signing configuration. The Release configuration currently uses an App Store provisioning profile, which cannot be installed directly on a device. Production continues to start from `lib/main.dart`.

## VS Code debugging and build tasks

Select **POPi - Demo (Mock UI)** in Run and Debug, select a simulator/device, then press F5. The launch configuration prepares the development environment and starts `lib/main_demo.dart` with breakpoints and hot reload.

Run these commands from **Terminal > Run Task**:

- `POPi: run demo`: run the demo from the terminal and select an available device.
- `POPi: build demo iOS simulator`: build `build/ios/iphonesimulator/Runner.app`.
- `POPi: build demo APK`: build `build/app/outputs/flutter-apk/app-release.apk`.
- `POPi: build demo IPA`: archive and export to `build/ios/ipa/` using the existing App Store signing configuration.

## GitHub Actions

Pushes to `dev-mockui` and pull requests from that branch run the existing format/analyze/test checks, then build Demo Android APK and iOS simulator artifacts. You can also manually run **Flutter Analyze and Test** on the selected branch. Download `popi-demo-android-apk-<run-id>` or `popi-demo-ios-simulator-<run-id>` from the run's Artifacts section.

The automatic APK uses release mode with an ephemeral debug signing key and requires no signing secrets. For a consistent distribution signature or an iPhone IPA, manually run **Flutter CI and Android Build**, select branch `dev-mockui`, set `Build environment` to `demo`, and select the desired platform. These builds reuse the existing signing secrets; their artifact names end in `-demo`. TestFlight upload runs only when explicitly selected for a manual build.

Extract the simulator artifact on a Mac, boot a compatible simulator, then install and open it:

```bash
tar -xzf popi-demo-ios-simulator.tar.gz
xcrun simctl install booted Runner.app
xcrun simctl launch booted com.popistudio.app
```

The simulator artifact is built for the GitHub macOS runner's architecture. The demo shares the production Bundle ID/application ID, so installing it replaces the existing app. Demo preferences are stored separately, but Android packages signed with different keys require uninstalling the previous installation first.

## Demonstration flow

1. Tap the conversation plus button to open the single-assistant sheet. Enter a conversation name of up to 15 characters, select one existing assistant, or create an assistant with a name, responsibilities, a zodiac avatar and a background color. The complete assistant configuration is saved with the conversation in one request; canceling leaves no draft assistant in the library.
2. Search or open an existing conversation, project or workflow. Sessions can be pinned or unpinned, while the overflow menu provides rename and delete actions.
3. New empty single-assistant conversations invite the user to link an existing content character or upload a DIY character. Content characters provide reference images and descriptions through `@` mentions; they do not become execution members. Up to five characters can be associated. Adding members is temporarily disabled, while existing group conversations and member editing remain available. Previously saved assistant identities can be selected for a separate conversation without copying its history.
4. Use the four suggested prompts in the offline Demo to show the bundled image, script, video and audio results. Tap the microphone to dictate into the current text selection, then tap it again to finish. Review the recognized text before sending; cancel discards the current dictation while retaining the original draft and attachments.
5. Switch to Outputs to see assets for that conversation. Return to the asset library to filter, search, switch between grid and list layouts, rename, delete and preview results.
6. In the offline Demo, the upload sheet selects bundled sample files. Removing a selection or dismissing the sheet does not change the library. Confirming publishes the whole selection in one atomic local save; a failed save leaves every selection available for retry.
7. Tap the avatar to open the existing profile page. To reset the mock data, open the welcome page, long-press the greeting, and choose Reset Demo.

## Mock Boundaries

- Replies and generated results are deterministic local fixtures, not live AI output.
- DIY characters save a stable identity, description and up to five image references. Harness uploads use the owned asset API; failed saves preserve the form and reuse already uploaded assets on retry. Local image uploads are not automatically published for cloud generation.
- Voice input uses the system recognizer on iOS, macOS and Android, and Web Speech recognition in supported browsers. Microphone and speech permissions are requested when used. Availability and network requirements depend on the system or browser; recognition failures retain the draft.
- Offline upload imports bundled samples and does not upload files to a server. Its batch is committed in one local snapshot, so persistence failure does not partially add files or clear the current selection.
- The video is an eight-second moving crop of the Figma illustration. The audio is a locally synthesized 24-second sample. Both play offline.
- The offline Demo persists character associations and assistant settings locally. Harness sends these settings as conversation configuration. DSH supplies the available tools, skills and MCP registrations; all six product capabilities are enabled by default, independently of character references and account preferences.
- Demo data is stored under `popi_ui_demo_v1`, separate from production account data. Reset affects only this demo snapshot.
- Figma images and icons are bundled locally; temporary Figma asset URLs are never used at runtime.

The Harness entry keeps the same interface but starts from real empty session and asset state. It supports text conversation, voice-to-text drafting, and real file uploads through the asset page's upper-left upload button. Files are stored by the local service and remain available across refresh and restart. The picker accepts PNG/JPEG/WebP images, MP4 video, TXT/MD scripts, and MP3/WAV/M4A audio. Failed batches retain selections and skip already successful files on resubmission. Uploading a file into this library does not yet make it a model reference attachment.

## Structure

- `lib/main_demo.dart`: separate launch entry point.
- `lib/features/demo/data/`: fixtures and local repository.
- `lib/features/demo/domain/`: demo models.
- `lib/features/demo/presentation/`: screens, chat synchronization and shared demo widgets.

When backend contracts become available, replace the local repository operations with feature repositories that use `NetworkAgentApi` or `NetworkApi`. Keep transport and streaming parsing outside the widgets.
