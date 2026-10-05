# MaPharmacie Mobile

Flutter companion application for the existing MaPharmacie React + Supabase SaaS. This folder is independent from the web application and uses the same Supabase Auth users, organizations, products, categories, RLS policies, and `lookup_product_by_barcode` RPC.

## Mobile Phase 1 scope

- Email/password login, restored Supabase sessions, redirects, and logout
- Active organization membership loading and multi-organization selection
- Home, Scan, Products, and Account navigation
- Camera and manual barcode scanning with a duplicate-scan lock
- Existing backend barcode RPC lookup and best-effort mobile scan telemetry
- Product result, unknown barcode, quick product creation, search, and detail
- Multi-product scan basket: confirm each scanned item without leaving the scanner, edit quantities, then check out the whole basket with cash or Tal9a
- Checkout checks warehouse stock, submits all lines in one `complete_sale` RPC, and prepares one WhatsApp receipt; legacy Moroccan phone numbers are normalized at handoff
- Initial warehouse stock during quick product creation
- Quick-add form places the actual available quantity beside the essential product details (zero allowed), accepts decimal commas, and supports inline category creation with automatic selection without losing the draft

No purchase reception, finance, OCR, external product lookup, or offline synchronization is included. The basket is in memory and resets on organization/session changes or app restart. WhatsApp opens a prepared message; the user must press Send. After an uncertain checkout network result, retry the same request without closing the app to avoid duplicate sales.

## Prerequisites

- Flutter stable 3.47 or newer
- Dart 3.12 or newer (required by Riverpod 3.4)
- Xcode and CocoaPods for iOS
- JDK 17 and an Android SDK with API 36 for Android (Android Studio or command-line tools)
- Access to the same Supabase project used by the web app

Android host files and launcher resources are included. To generate missing iOS host files on a Mac with Xcode:

```bash
flutter create --platforms=ios --org com.mapharmacie .
```

Keep these camera-specific project changes if Flutter reports conflicts:

- `android/app/src/main/AndroidManifest.xml`: `CAMERA`, optional camera features
- `android/app/build.gradle.kts`: `compileSdk = flutter.compileSdkVersion`, `minSdk = 24`
- `ios/Runner/Info.plist`: `NSCameraUsageDescription`
- `ios/Podfile`: iOS 15.5 and `PERMISSION_CAMERA=1`

## Environment

Create the ignored runtime definition file:

```bash
cp config/env.example.json config/env.json
```

Fill it with the web application's Supabase project URL and public anon/publishable key:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_PUBLIC_ANON_OR_PUBLISHABLE_KEY"
}
```

Never use the service-role key in Flutter. These values are compiled into the client, so authorization remains enforced by Supabase Auth and RLS—not by secrecy of the public client key.

## Install and run

```bash
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/env.json
```

Choose a physical Android/iOS device for reliable camera verification. To create an APK for direct installation on an Android phone:

```bash
flutter build apk --release --dart-define-from-file=config/env.json
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk` and requires Android 7.0 (API 24) or newer. Transfer it to the phone, open it, and allow installation from that file manager when Android prompts. Internet access is required for login and Supabase data. The current release build uses the local debug signing key for personal testing; configure a dedicated release signing key before publishing to Google Play.

To create store artifacts after configuring release signing:

```bash
flutter build appbundle --release --dart-define-from-file=config/env.json
flutter build ios --release --dart-define-from-file=config/env.json
```

## Existing backend contract

The app expects the existing migrations to be applied, especially:

- foundation tables/functions for `profiles`, `organizations`, and `organization_members`
- product catalog tables and RLS for `categories` and `products`
- `lookup_product_by_barcode(text, uuid)`, `normalize_barcode`, and `scan_events`
- `get_dashboard_summary` for the reliable dashboard metrics

No mobile-only database tables or migrations were created. The lookup RPC remains authoritative for tenant membership and normalized indexed barcode resolution. Product search and quick creation use the existing tables through authenticated RLS.

## Architecture

The code is feature-oriented: app routing and shell in `lib/app`, shared environment/theme/error/Supabase utilities in `lib/core`, and repositories, immutable models, providers, and presentations under `lib/features`. Riverpod owns shared async state; transient camera, form, and scan-lock state stays local to its screen.

See [docs/TESTING.md](docs/TESTING.md) for the Mobile Phase 1 verification checklist.
# mapharmacie-mobile
