# Hoppin Driver — Mobile App

The driver-facing Flutter app for Hoppin, a UK ride-hailing platform (West
Midlands / Wolverhampton licensing area). **Android only** — a browser tab
cannot hold a driver's shift (background geolocation is unavailable to a
backgrounded web tab), so the driver app targets native Android.

## Layout

This is a Dart pub **workspace**. The app and its shared packages live side by
side:

```
pubspec.yaml            workspace root
driver_app/             the Flutter app (lib, android, test)
packages/
  hoppin_shared/        API client, repositories, models, providers
  hoppin_ui/            design system (tokens, components)
  hoppin_demo/          offline demo world + fake repositories
```

The three packages are vendored copies shared with the rider app; keep changes
to them in sync across the two repos.

## Setup

1. Install Flutter (3.12+) and the Android toolchain.
2. Copy the config template and fill in real values:
   ```
   cp driver_app/demodefines.example.json driver_app/demodefines.json
   ```
   `demodefines.json` holds the Supabase key + demo credentials and is
   git-ignored — never commit it.
3. Resolve dependencies from the repo root:
   ```
   flutter pub get
   ```

## Build & run

```
cd driver_app
flutter run   --dart-define-from-file=demodefines.json          # debug on device/emulator
flutter build apk --dart-define-from-file=demodefines.json      # release APK
```

> Android emulator note: `localhost` is the emulator, not the host. Point
> `RIDE_SERVICE_URL` at `http://10.0.2.2:8080/api/v1` for a host-local backend.

## Test

```
flutter test           # from the repo root, or inside driver_app/
```
