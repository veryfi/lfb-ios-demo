# LFB iOS Demo

A minimal native iOS app that runs [Veryfi Lens for Browser](https://docs.veryfi.com/lens/browser-v3/getting-started/quick-start/general/) (`veryfi-lens-wasm`) inside a `WKWebView`. Use it to reproduce and debug issues that only show up when the SDK is opened from a native app instead of Safari.

The app serves a small web page from `http://127.0.0.1` inside the app and loads it in a full-screen web view. From that page you can:

- Start a capture with the **Receipt** (`document`), **Long receipt** (`long_document`), or **Anydocs** (`anydocs`) flavor. Anydocs opens the blueprint picker (`enableBlueprintsModal: true`) before the camera, and the chosen blueprint is sent as `blueprint_name`. Anydocs also has `multiSubmission: true`, so several documents can be captured in one session; each one is submitted separately and gets its own row in the table.
- Start a **Decoupled receipt** capture: the `document` flavor with `packageMode: false` and a `customSubmitHandler` ([decoupled submission, mode 2](https://docs.veryfi.com/lens/browser-v3/advanced/decoupled_submission/#mode-2-custom-submit-handler)). The Submit button stays; on tap Lens passes the base64 image to the handler (package info is `null`) instead of submitting to Veryfi, so no document is processed.
- See every document submitted in the current session in a table (flavor, capture time, document ID), with the JSON response for each row expandable. Decoupled rows have no document ID.

## Requirements

- macOS with Xcode 16 or later
- Node.js (current LTS)
- An iPhone or iPad running iOS 16 or later (the simulator has no camera)
- An Apple ID added to Xcode (a free personal team works)
- A Veryfi account with Lens for Browser enabled, and its **Client ID** from [Veryfi Hub → Settings → Keys](https://app.veryfi.com/api/settings/keys/)

## Setup

1. Install dependencies:

   ```bash
   npm install
   ```

2. Create `.env` in the repository root and add your Client ID:

   ```bash
   cp .env.example .env
   ```

   ```
   VITE_VERYFI_CLIENT_ID=your_client_id_here
   ```

3. Create your signing config:

   ```bash
   cp Config/Signing.example.xcconfig Config/Signing.xcconfig
   ```

   Set `DEVELOPMENT_TEAM` to your team ID (Xcode → Settings → Accounts, or [Membership details](https://developer.apple.com/account)). Set `PRODUCT_BUNDLE_IDENTIFIER` to an ID that is unique to your team, for example `com.yourname.lfbiosdemo`. Bundle IDs are registered per Apple account, so the example value may already be taken.

   Both `.env` and `Config/Signing.xcconfig` are git-ignored.

4. Build the web page:

   ```bash
   npm run build
   ```

   This writes the page to `dist/`. The Xcode build copies `dist/` into the app and fails if it is missing.

5. Open `LFBiOSDemo.xcodeproj`, select your device, and press **Run**.

   The first time you install on a device, trust the developer certificate on the phone under **Settings → General → VPN & Device Management**, then run again.

Run `npm run build` again, then rebuild the app, after any change to `web/`, `.env`, or the SDK version.

## Debugging

- JavaScript `console` output is forwarded to the Xcode debug console with a `[lens]` prefix.
- The web view is inspectable (iOS 16.4 and later): on the Mac, open Safari → **Develop** → your device → the page.
- Lens runs with `debug_mode: true`, so the logs include SDK state and detector output. Set it to `false` in `web/main.js` for quieter logs.
- Lines from `WebContent`, `sandbox_extension`, `AppleAVD`, `MDNS`, and similar are iOS and WebKit system messages, not Lens errors.

## Notes on running Lens in a WKWebView

These are the settings that make the SDK work in an in-app browser. They are also the first things to check when a client's native integration misbehaves.

- **Serve the page from `http://127.0.0.1`, not `file://`.** Camera access (`getUserMedia`) requires a secure context. `LocalWebServer.swift` serves the bundled page on a random local port.
- **Grant camera access in the web view.** `LensBrowserView.swift` implements `webView(_:requestMediaCapturePermissionFor:initiatedByFrame:type:decisionHandler:)` and returns `.grant`. `Info.plist` must include `NSCameraUsageDescription`. Without both, `getUserMedia` fails and Lens hides its on-camera buttons.
- **Allow inline playback.** `allowsInlineMediaPlayback = true` and `mediaTypesRequiringUserActionForPlayback = []`, so the camera preview plays in the page instead of the fullscreen player.
- **Turn off Vite module preloading.** `WKWebView` reports `<link rel="modulepreload">` as supported but never finishes it, so the SDK's dynamic flavor import in `showCamera` never resolves and Lens stays on "Initializing...". `vite.config.js` sets `modulePreload: false` and inlines dynamic imports.
- **Don't start Lens with a top-level `await`.** `web/main.js` calls `init` and `showCamera` from a function after the module has finished loading.

## Project layout

```
Config/                    Shared build settings and the signing template
LFBiOSDemo/                Native app: SwiftUI entry point, web view, local server
LFBiOSDemo.xcodeproj/      Xcode project
web/                       The page loaded in the web view
vite.config.js             Web build settings
```

## License

[MIT](LICENSE)
