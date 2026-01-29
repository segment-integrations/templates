# Segment Templates (mobile)

Shared Devbox plugins and example projects for Android, iOS, and React Native.

## Devbox plugins
- `devbox/plugins/android` — Android SDK + emulator management in a project-local virtenv.
- `devbox/plugins/ios` — iOS toolchain + simulator management for macOS.
- `devbox/plugins/react-native` — Composition of Android + iOS plugins.

## Examples
- `devbox/examples/android` — Minimal Android app wired to the Android plugin.
- `devbox/examples/ios` — Swift package initialized via the iOS plugin.
- `devbox/examples/react-native` — React Native app wired to Android + iOS plugins.

## Android plugin highlights
- Device definitions live in `devbox.d/android/devices/*.json`.
- Use `devbox run --pure android.sh devices list|create|update|delete` to manage devices.
- `EVALUATE_DEVICES` in `devbox.d/android/android.json` limits which device APIs are evaluated by the flake (empty means all).
- `devbox run --pure start-emu [device]` boots an emulator.
- `devbox run --pure start-app [device]` builds/installs/launches on the resolved emulator.
See `devbox/plugins/android/REFERENCE.md` for the full Android reference.

## iOS plugin highlights
- Simulator definitions live in `devbox.d/ios/devices/*.json`.
- `devbox run --pure start-sim [device]` boots a simulator.
- `devbox run --pure stop-sim` stops it.
See `devbox/plugins/ios/REFERENCE.md` for the full iOS reference.

## React Native plugin highlights
- Composes the Android + iOS plugins.
- Android: `devbox run --pure start-emu`, `devbox run --pure start-app`, `devbox run --pure stop-emu`.
- iOS: `devbox run --pure start-sim`, `devbox run --pure stop-sim`.
See `devbox/plugins/react-native/REFERENCE.md` for the full React Native reference.

## CI quickstart
GitHub Actions workflows live in `.github/workflows/` and exercise emulator/simulator start/stop with `--pure`.
