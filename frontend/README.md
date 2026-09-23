# Handover App (Flutter)

Flutter client for Handover: search nearby skills, send requests, chat in
private rooms, rate neighbors and send tips.

## Requirements

- Flutter 3.x (`flutter --version`)
- A running backend (see `../backend/README.md`)

## Setup

```bash
flutter pub get
cp .env.example .env   # then set API_BASE_URL to your backend
```

## Run

```bash
# Local backend on the same machine
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:9000

# Android emulator (host loopback)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:9000
```

Copying `.env` is optional: `--dart-define=API_BASE_URL=...` always wins
when provided. `ONESIGNAL_APP_ID` and `REVENUECAT_API_KEY` are optional;
without them push stays disabled and tipping runs in debug mock mode.

## Tests and checks

```bash
flutter test
flutter analyze
dart format lib test
```

## Notes

- Location is foreground-only and coarse by design. The app shows a
  prominent disclosure before requesting permission and works with a
  manually picked area if permission is denied.
- Release builds require `https://` API URLs (asserted in `lib/services/api.dart`).
  Cleartext HTTP is debug-only for LAN development.
