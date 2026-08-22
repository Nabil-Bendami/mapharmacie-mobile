# MaPharmacie Mobile

Flutter companion application for the existing MaPharmacie React + Supabase SaaS. This folder is independent from the web application and uses the same Supabase Auth users, organizations, products, categories, RLS policies, and `lookup_product_by_barcode` RPC.

## Mobile Phase 1 scope

- Email/password login, restored Supabase sessions, redirects, and logout
- Active organization membership loading and multi-organization selection
- Home, Scan, Products, and Account navigation
- Camera and manual barcode scanning with a duplicate-scan lock
- Existing backend barcode RPC lookup and best-effort mobile scan telemetry
- Product result, unknown barcode, quick product creation, search, and detail

No POS, purchase reception, stock mutations, finance, OCR, external product lookup, offline synchronization, or other Mobile Phase 2 workflows are included.

## Prerequisites

- Flutter stable 3.47 or newer
- Dart 3.12 or newer (required by Riverpod 3.4)
- Xcode and CocoaPods for iOS
- Android Studio/JDK 17 and an Android SDK with API 35 for Android
- Access to the same Supabase project used by the web app

This machine did not have Flutter or Dart installed when the project source was created. After installing Flutter, generate any SDK-owned host files (Gradle wrapper, Xcode project, launch assets) from this directory:

```bash
cd /Users/nabil/Documents/my-project/MaPharmacie-Mobile
flutter create --platforms=android,ios --org com.mapharmacie .
```

Keep these camera-specific project changes if Flutter reports conflicts:

- `android/app/src/main/AndroidManifest.xml`: `CAMERA`, optional camera features
- `android/app/build.gradle.kts`: `compileSdk = 35`, `minSdk = 23`
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

Choose a physical Android/iOS device for reliable camera verification. To create release artifacts:

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
