# POPi App Development

This branch uses `lib/main.dart` as its only application entry point in development and production. It implements the creation flows from Figma section `2056:3269` with local mock data. The avatar opens the existing profile and account pages, which retain their normal backend behavior and signed-in account.

## Run on a phone

```bash
flutter pub get
flutter devices
dart run tool/flutter_env.dart development run --profile -d <device-id>
```

For a simulator, omit `--profile`. Profile mode can run independently on a phone and uses this project's existing development signing configuration. The Release configuration currently uses an App Store provisioning profile, which cannot be installed directly on a device. Both the environment script and direct Flutter commands use `lib/main.dart` by default.

## VS Code debugging and build tasks

Select **POPi - Development** in Run and Debug, select a simulator/device, then press F5. Use **POPi - Production** for the production environment. Both configurations start `lib/main.dart` with breakpoints and hot reload.

Run these commands from **Terminal > Run Task**:

- `POPi: run`: run the app from the terminal and select an available device.
- `POPi: build iOS simulator`: build `build/ios/iphonesimulator/Runner.app`.
- `POPi: build APK`: build `build/app/outputs/flutter-apk/app-release.apk`.
- `POPi: build IPA`: archive and export to `build/ios/ipa/` using the existing App Store signing configuration.

## GitHub Actions

Pushes to `dev-mockui` and pull requests from that branch run the existing format/analyze/test checks, then build Android APK and iOS simulator artifacts. You can also manually run **Flutter Analyze and Test** on the selected branch. Download `popi-android-apk-<run-id>` or `popi-ios-simulator-<run-id>` from the run's Artifacts section.

The automatic APK uses release mode with an ephemeral debug signing key and requires no signing secrets. For a consistent distribution signature or an iPhone IPA, manually run **Flutter CI and Android Build**, select branch `dev-mockui`, set `Build environment` to `dev` or `production`, and select the desired platform. These builds reuse the existing signing secrets. Development artifact names end in `-dev`. TestFlight upload runs only when explicitly selected for a manual build.

Extract the simulator artifact on a Mac, boot a compatible simulator, then install and open it:

```bash
tar -xzf popi-ios-simulator.tar.gz
xcrun simctl install booted Runner.app
xcrun simctl launch booted com.popistudio.app
```

The simulator artifact is built for the GitHub macOS runner's architecture. Development and production builds share the Bundle ID/application ID, so installing either replaces the existing app. Android packages signed with different keys require uninstalling the previous installation first.

## Demonstration flow

Signed-out users first see the default POPi home (`3714:1667`). The sign-in button and composer open the existing login page. After the first sign-in for each account, the existing five-step IP guide collects choices locally and shows a final review. Confirming creates one local project session and opens its chat. The session configuration and completion record are saved together under `popi_ui_demo_v1`; subsequent launches and sign-ins skip the guide. Deleting that session or resetting sample data does not reset onboarding. Clearing app data removes these local completion records.

Unfinished guide drafts are saved per account under `v2_onboarding_draft_v1:<userId>`. A failed confirmation keeps the draft and request identifier for the next confirmation. This branch uses bundled guide choices and the local V2 repository, so this flow does not call the production account creation or Agent session endpoints.

1. Search or open a conversation, project or workflow.
2. Use the four suggested prompts to create image, script, video and audio results.
3. Open the top-right conversation settings. Rename the conversation, select characters, add assistants, edit assistant names/instructions and toggle capabilities.
4. Switch to Outputs to see assets for that conversation.
5. Return to the asset library to filter, search, rename, delete and preview results. The upload action imports a bundled sample.
6. Tap the avatar to open the existing profile page. To reset the mock data, open the welcome page with the plus button, long-press the greeting, and choose Reset Demo.

## Mock Boundaries

- Replies and generated results are deterministic local fixtures, not live AI output.
- Character creation reuses a bundled portrait with the entered name.
- The microphone action inserts a sample transcript. It does not record audio.
- Upload imports bundled samples and does not upload files to a server.
- The video is an eight-second moving crop of the Figma illustration. The audio is a locally synthesized 24-second sample. Both play offline.
- Character associations, assistant settings and capability toggles persist locally; they do not change a live Agent's behavior.
- Demo data is stored under `popi_ui_demo_v1`, separate from production account data. Reset affects only this demo snapshot.
- Figma images and icons are bundled locally; temporary Figma asset URLs are never used at runtime.

## Structure

- `lib/main.dart`: the application's only launch entry point.
- `lib/app/v2_app.dart`: application setup and routing.
- `lib/features/v2_home/`: home, conversation list and welcome screens.
- `lib/features/v2_session/`: chat, conversation settings and chat controller.
- `lib/features/v2_assets/`: asset library, media previews and export.
- `lib/features/v2_shared/`: fixtures, models, local repository and shared widgets.

When backend contracts become available, replace the local repository operations with feature repositories that use `NetworkAgentApi` or `NetworkApi`. Keep transport and streaming parsing outside the widgets.
