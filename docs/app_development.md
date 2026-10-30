# POPi App Development

This branch uses `lib/main.dart` as its only application entry point in development and production. The new Figma interface uses the POPiBot `/api_agent/v2` contracts. The avatar opens the existing profile and account pages.

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

## Connected flow

Signed-out users see the default POPi home (`3714:1667`). The sign-in button and composer open the existing login page. After sign-in, the app loads owned sessions, including an archived-session check when the active list is empty. An account with no prior sessions or local completion record enters the existing IP guide. Its choices stay local until preview confirmation sends one configured project session creation request, then opens chat. A persistent request ID makes confirmation retries idempotent.

Unfinished guide drafts are saved per account under `v2_onboarding_draft_v1:<userId>`. Completion is stored under `popi_v2:<Agent origin>:<userId>:onboarding`; deleting the first session does not reset it. Existing server sessions skip onboarding on another device. There is no server onboarding flag in the template: clearing local storage after every server session has been deleted can show the guide again. Guide options are bundled and localized.

1. Search or open a conversation, project or workflow.
2. Send prompts and existing library attachments. Accepted input clears immediately; snapshots update messages, generated assets and run state. The stop action and versioned question answers use the server contracts.
3. Open the top-right conversation settings. Rename the conversation, select characters, add assistants, edit assistant names/instructions and toggle capabilities.
4. Switch to Outputs to see assets for that conversation.
5. Return to the asset library to filter, search, rename, delete, preview and export original media. Upload picks real files, validates their types and sizes, obtains a direct-upload lease, then imports the completed business asset into Agent. Successfully uploaded files are removed from the selection; failed files remain available for another submission.
6. Select official or personal characters, or create a character with instructions and reference images. Up to five characters can be linked to a session.
7. Tap the avatar to open the existing profile page.

## Integration Notes

- `AGENT_API_BASE_URL`, `AGENT_API_ORIGIN` and `API_BASE_URL` remain in `config/env/*.json`; use the environment runner above. The configured endpoint must serve the business POPiBot routes and accept the normal business login identity.
- Each login captures its token in separate Agent and asset-library transports. Account changes dispose polling and uploads. Private image cache keys include credentials; public CDN downloads and object-storage uploads receive no Agent token.
- Session PATCH sends `expectedConfigRevision`, preserves unedited configuration fields and refreshes on `config_conflict`. Failed edits retain form input.
- The microphone has no speech-recognition integration. The existing composer voice behavior is unchanged.
- Advanced template features such as style-film catalogs, storyboard review and media-model preflight have no controls in this interface and are not exposed here.
- The fixture-backed `V2Repository` and `popi_ui_demo_v1` remain available for isolated widget tests. The app uses `V2RemoteRepository` after login and never imports fixture sessions into an account.
- Figma images and icons are bundled locally; temporary Figma asset URLs are never used at runtime.

## Structure

- `lib/main.dart`: the application's only launch entry point.
- `lib/app/v2_app.dart`: application setup and routing.
- `lib/features/v2_home/`: home, conversation list and welcome screens.
- `lib/features/v2_session/`: chat, conversation settings and chat controller.
- `lib/features/v2_assets/`: asset library, media previews and export.
- `lib/features/v2_shared/`: models, remote repository, upload validation, fixtures and shared widgets.
- `lib/shared/providers/v2_repository_provider.dart`: account ownership and remote bootstrap.

Contract tests use intercepted requests, without real login, generation or paid API calls. Live deployment availability and real-device uploads/downloads still require testing with a signed-in account.
