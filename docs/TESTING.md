# Mobile Phase 1 verification

Run automated checks first:

```bash
flutter analyze
flutter test
```

Then use a physical device and the same Supabase project as the web application.

## Authentication and organization

- Launch without a stored session: login is shown.
- Log in using an existing MaPharmacie web account.
- Relaunch: the session restores without another login.
- A single active membership is selected automatically.
- Multiple active memberships show the pharmacy chooser.
- An account without active membership sees the safe no-organization state.
- Logout clears the session and returns to login.

## Scanner

- Grant camera access and verify the preview starts.
- Deny once and verify the retry explanation; permanently deny and verify Open settings.
- Background/resume and leave/re-enter the scanner; the camera stops and resumes correctly.
- Toggle the flash on supported hardware.
- Scan EAN-13, EAN-8, UPC, Code 128, and QR samples where available.
- Hold one barcode in frame and verify only one lookup/navigation occurs.
- Enter a barcode manually and verify it follows the same lookup path.
- Verify a barcode beginning with zero keeps that zero.
- Disable connectivity and verify a friendly retryable network message.

## Products and tenant security

- A known barcode opens the scan result and shows real product fields.
- Scan another returns to the camera; View product opens the normal detail route.
- An unknown barcode shows the scanned value, Scan again, and Add product.
- Quick add keeps the barcode read-only and unchanged, then opens the created product.
- Search server-side by name, barcode, SKU, and brand; verify pagination.
- Use two organizations and confirm products/categories never cross tenants.
- Try a different organization's product UUID directly and confirm RLS returns no product.

## Native builds

- `flutter build appbundle --release --dart-define-from-file=config/env.json`
- `flutter build ios --release --dart-define-from-file=config/env.json`
- Inspect release permission prompts: only the camera permission is requested by this Phase 1 app.
