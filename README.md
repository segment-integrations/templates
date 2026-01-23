# Segment Templates (mobile)

Shared flake definitions for Android SDK variants used by mobile projects.

## Flake dirs
- `envs/android/min` — API 21 SDK with emulator/system images (google_apis).
- `envs/android/max` — API 33 SDK with emulator/system images (google_apis).

## Using in flox manifests
Set the flake reference to the desired dir, e.g.:

```toml
[install]
android-sdk.flake = "github:segment-integrations/templates?dir=envs/android/max"
```

Then regenerate locks (`yarn update:flox` or `flox update`).
