# flutter_readium

[![pub package](https://img.shields.io/pub/v/flutter_readium.svg)](https://pub.dev/packages/flutter_readium)
[![Quality](https://github.com/notalib/flutter_readium/actions/workflows/quality.yml/badge.svg?branch=main)](https://github.com/notalib/flutter_readium/actions/workflows/quality.yml)
[![Unit Tests](https://github.com/notalib/flutter_readium/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/notalib/flutter_readium/actions/workflows/test.yml)
[![CI](https://github.com/notalib/flutter_readium/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/notalib/flutter_readium/actions/workflows/ci.yml)

A Flutter plugin for reading EPUB, audiobook, and WebPub publications, wrapping the [Readium](https://readium.org) toolkits behind a unified Dart API.

flutter_readium is a federated Flutter plugin that delegates to the upstream Readium toolkits on each platform:

- **swift-toolkit 3.11.0** on iOS
- **kotlin-toolkit 3.3.0** on Android
- **ts-toolkit** (`@readium/shared`, `@readium/navigator`) on Web

## Features

- EPUB 2 / EPUB 3 reading, with dynamic horizontal pagination and vertical scrolling modes
- PDF reading on iOS (PDFKit) and Android (PDFium), with layout, reading-progression, page-spacing, and fit preferences
- WebPub reading (including audiobook WebPub)
- Pre-recorded audio playback with track navigation and variable speed
- Synchronized Media Overlays (text-and-audio read-along)
- Platform-native text-to-speech with voice selection, speed, and pitch
- Reader preferences (typography, scroll, columns, ...) via the Readium Preferences API
- App-supplied static reader fonts on iOS, Android, and Web
- Highlights and annotations via the Decorator API
- Position persistence and restoration via Locators
- Content search within open publications
- Real-time event streams for position, playback state, reader status, and errors
- Custom HTTP headers for publication and resource fetching

## Supported formats

| Format    | Visual       | TTS | Audio | Media Overlays         |
| --------- | :----------: | :-: | :---: | :--------------------: |
| EPUB 2    |      ✓       |  ✓  |   —   |           -            |
| EPUB 3    |      ✓       |  ✓  |   ✓   |           -            |
| WebPub    |      ✓       |  ✓  |   ✓   | ✓ (EPUB profile)       |
| Audiobook |      —       |  —  |   ✓   |           -            |
| PDF       |      ✓       |  —  |   —   |           -            |

CBZ and DIVINA publications are not currently supported. LCP-protected publications are supported by the underlying toolkits but are **disabled by default** in this plugin — see [LCP (DRM) support](#lcp-drm-support).

## Platform support

| Feature                  | Android | iOS | Web        |
| ------------------------ | :-----: | :-: | :--------: |
| EPUB visual reading      |    ✓    |  ✓  |     ✓      |
| PDF reading              |    ✓    |  ✓  |     —      |
| Audiobook playback       |    ✓    |  ✓  |     ✓      |
| Media Overlays           |    ✓    |  ✓  |     —      |
| Text-to-Speech           |    ✓    |  ✓  | Limited¹   |
| Highlights / decorations |    ✓    |  ✓  |     ✓      |
| Reader preferences       |    ✓    |  ✓  |     ✓      |
| PDF preferences          |    ✓    |  ✓  |     —      |
| Progress saving          |    ✓    |  ✓  |     ✓      |
| Content search           |    ✓    |  ✓  |     —      |
| Background audio         |    ✓    |  ✓  |     —      |

¹ Web TTS uses the browser's Web Speech API — voice availability and quality vary by browser.

> **macOS note:** Native macOS desktop (`flutter run -d macos`) is not supported — a no-op stub is registered so the Flutter macOS target still compiles, but every reader call returns `MethodNotImplemented`. The upstream `swift-toolkit` is iOS-only and has marked native macOS [`not_planned`](https://github.com/readium/swift-toolkit/issues/783). The iOS build runs fine on Apple Silicon Macs via "Designed for iPad".

## LCP (DRM) support

[Readium LCP](https://readium.org/lcp/) (Licensed Content Protection) is the Readium Foundation's
open DRM solution. LCP-protected EPUBs ship as `.epub` (or `.lcpl` license files) whose content is
encrypted; a valid **User Passphrase** decrypts them on the reader.

This plugin ships with the necessary **native scaffolding already present but disabled by default**.
The upstream `swift-toolkit` and `kotlin-toolkit` LCP modules are vendored into the platform builds,
but no LCP client/auth is wired up, so DRM-protected books cannot be opened yet.

### How LCP fits the toolkits

| Layer | iOS (swift-toolkit) | Android (kotlin-toolkit) |
| ----- | ------------------- | ------------------------ |
| Service | `LCPService` (`Sources/LCP/LCPService.swift`) | `LcpService` (`readium/lcp/.../LcpService.kt`) |
| Auth | `LCPDialogAuthentication` / `LCPPassphraseAuthentication` / custom `LCPAuthenticating` | `LcpPassphraseAuthentication` / custom `LcpAuthenticating` |
| Client (decryption) | Your app wraps the private `R2LCPClient.framework` in a `LCPClient` facade | Implement the `LcpClient` decryption facade |
| Repositories | `LCPLicenseRepository` (e.g. SQLite adapter) + `LCPPassphraseRepository` | `LicensesRepository` + `PassphrasesRepository` |
| Content protection | `contentProtection(with:)` → passed to `PublicationOpener` | `LcpContentProtection` → added to the opener's `contentProtections` |

On both platforms the flow is the same: when a publication is LCP-protected, the toolkit's
content protection asks its **authenticator** for a passphrase, validates it against the license,
then transparently decrypts the assets.

### Current state in this fork

- **iOS** (`flutter_readium/ios/flutter_readium/Sources/flutter_readium/Readium.swift`) — a full LCP
  block already exists behind `#if LCP`, creating `LCPService` with SQLite license/passphrase
  repositories and a private `R2LCPClient` facade. It is **compiled out** because the `LCP` flag is
  undefined, the `ReadiumLCP` / `ReadiumAdapterLCPSQLite` pods are commented out in
  `flutter_readium.podspec`, and `R2LCPClient.framework` is not linked.
- **Android** (`flutter_readium/android/build.gradle`) — the `readium-lcp` module dependency is
  commented out and there is no `Lcp` wiring in `ReadiumReader.kt`. Any `ContentProtection` list the
  `PublicationOpener` is built with today is empty.

### Enabling LCP

Enabling DRM support requires changes on every native side plus a Dart API to supply the passphrase.
This is intentionally left disabled in the stock plugin (LCP needs a licensed `R2LCPClient`/`liblcp`
binary and product decisions about passphrase UX). Enabling involves:

1. **iOS** — uncomment the `ReadiumLCP`/`ReadiumAdapterLCPSQLite` pods in `flutter_readium.podspec`,
   link the private `R2LCPClient.framework`, and define the `LCP` preprocessor flag so the
   `#if LCP` block in `Readium.swift` compiles.
2. **Android** — uncomment `org.readium.kotlin-toolkit:readium-lcp` in `android/build.gradle` and
   register `LcpContentProtection` (with a license/passphrase repository and an `LcpAuthenticating`
   implementation) in the `PublicationOpener` in `ReadiumReader.kt`.
3. **Dart** — add a method-channel API on `FlutterReadium` so the app can pass a passphrase back to
   the native authenticator (e.g. a `LCPDialogAuthentication` that hands off to Dart instead of
   prompting natively).
4. **App integration** — the consuming app (YouScribe) must obtain the passphrase from its own
   backend/LSD proxy and forward it through the plugin.

## Minimum requirements

| Requirement | Version                |
| ----------- | ---------------------- |
| Flutter     | 3.44.4+                |
| Dart SDK    | 3.8.0+                 |
| Android     | `minSdkVersion` 24     |
| iOS         | 15.0+                  |

## Getting started

Add the dependency to your app's `pubspec.yaml`:

```yaml
dependencies:
  flutter_readium: ^x.y.z
```

Then complete the per-platform setup below. See the [installation guide](https://github.com/notalib/flutter_readium/blob/main/docs/getting-started/installation.md) and the [quick-start walkthrough](https://github.com/notalib/flutter_readium/blob/main/docs/getting-started/quick-start.md) for details.

### Android

- Set `minSdkVersion` to 24 or higher in `android/app/build.gradle`.
- Change your `MainActivity` to extend `FlutterFragmentActivity` (not `FlutterActivity`) — otherwise the reader view will crash at runtime.
- If using TTS or background audio, add to `android/app/src/main/AndroidManifest.xml`:

  ```xml
  <uses-permission android:name="android.permission.WAKE_LOCK" />
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
  ```

### iOS

Add the Readium pods to your `ios/Podfile`. The versions must match the ones pinned in
`ios/flutter_readium.podspec`. The `example/ios/Podfile` is the source-of-truth for app
integration — copy these lines into your own `Podfile`:

```ruby
source 'https://github.com/readium/podspecs'
source 'https://cdn.cocoapods.org/'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  pod 'ReadiumShared', '~> 3.11.0'
  pod 'ReadiumInternal', '~> 3.11.0'
  pod 'ReadiumStreamer', '~> 3.11.0'
  pod 'ReadiumNavigator', '~> 3.11.0'
  pod 'ReadiumOPDS', '~> 3.11.0'
end
```

The `readium/podspecs` source is hosted at https://github.com/readium/podspecs. To use
a specific version, change the `~>` constraint accordingly (e.g. `~> 3.10.0`).

### Web

1. Copy the plugin's JavaScript bundle into your web app:

   ```bash
   dart run flutter_readium:copy_js_file <destination_directory>
   ```

   The destination should live inside your `web/` directory.

2. Reference the script from `web/index.html`:

   ```html
   <script src="flutter.js" defer></script>
   <script src="readiumReader.js" defer></script>
   ```

## Documentation

Full documentation is hosted in the [project repository](https://github.com/notalib/flutter_readium):

- **Getting Started** — [Installation](https://github.com/notalib/flutter_readium/blob/main/docs/getting-started/installation.md) · [Quick Start](https://github.com/notalib/flutter_readium/blob/main/docs/getting-started/quick-start.md) · [Core Concepts](https://github.com/notalib/flutter_readium/blob/main/docs/getting-started/concepts.md)
- **Guides** — [EPUB Reading](https://github.com/notalib/flutter_readium/blob/main/docs/guides/epub-reading.md) · [Audiobook Playback](https://github.com/notalib/flutter_readium/blob/main/docs/guides/audiobook-playback.md) · [Text-to-Speech](https://github.com/notalib/flutter_readium/blob/main/docs/guides/text-to-speech.md) · [Preferences](https://github.com/notalib/flutter_readium/blob/main/docs/guides/preferences.md) · [Highlights & Annotations](https://github.com/notalib/flutter_readium/blob/main/docs/guides/highlights-annotations.md) · [Search](https://github.com/notalib/flutter_readium/blob/main/docs/guides/search.md) · [Custom HTTP Headers](https://github.com/notalib/flutter_readium/blob/main/docs/guides/http-headers.md) · [Saving Progress](https://github.com/notalib/flutter_readium/blob/main/docs/guides/saving-progress.md) · [Error Handling](https://github.com/notalib/flutter_readium/blob/main/docs/guides/error-handling.md)
- **API Reference** — [FlutterReadium class](https://github.com/notalib/flutter_readium/blob/main/docs/api-reference/flutter-readium.md) · [ReaderWidget](https://github.com/notalib/flutter_readium/blob/main/docs/api-reference/reader-widget.md) · [Locator](https://github.com/notalib/flutter_readium/blob/main/docs/api-reference/locator.md) · [Preferences](https://github.com/notalib/flutter_readium/blob/main/docs/api-reference/preferences.md) · [Decorations](https://github.com/notalib/flutter_readium/blob/main/docs/api-reference/decorations.md) · [Streams & Events](https://github.com/notalib/flutter_readium/blob/main/docs/api-reference/streams-events.md) · [Publication](https://github.com/notalib/flutter_readium/blob/main/docs/api-reference/publication.md)
- **Architecture** — [Overview](https://github.com/notalib/flutter_readium/blob/main/docs/architecture.md)
- **Troubleshooting** — [Troubleshooting](https://github.com/notalib/flutter_readium/blob/main/docs/troubleshooting.md)

The generated Dart API reference is also published on [pub.dev](https://pub.dev/documentation/flutter_readium/latest/).

## Example app

A complete example app is available in the repository at [flutter_readium/example/](https://github.com/notalib/flutter_readium/tree/main/flutter_readium/example), demonstrating EPUB and audiobook reading, TTS, preferences, and highlighting.

## License

BSD 3-Clause — see [LICENSE](https://github.com/notalib/flutter_readium/blob/main/LICENSE).
