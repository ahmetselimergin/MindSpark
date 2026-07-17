# MindSpark playable core

MindSpark is an Android-first Flutter + Flame color-connect puzzle slice. It
ships three validated 5×5 levels, local progress, idempotent 100-point scoring,
and the complete Splash → Home → Game → Result → next/home flow.

## Architecture

- `lib/game/domain/` owns deterministic puzzle rules and immutable snapshots.
  It has no Flutter or Flame dependency.
- `lib/game/mind_spark_game.dart` is the Flame adapter. It maps pointer input
  and canvas coordinates to the domain session and renders the board.
- `lib/features/` and `lib/app/` own Flutter screens and navigation. Riverpod
  coordinates validated level assets and progress repositories; Hive provides
  on-device persistence.

The bundled levels and gameplay loop work fully offline. Dependency resolution
and the first Android toolchain setup can still require network access.

Hive progress is loaded as one atomic version-1 record. A missing record starts
with defaults; a malformed record, unsupported schema, or inconsistent
score/unlock data is diagnosed through the repository callback and resets the
whole record to defaults rather than salvaging individual fields. Storage read
failures are surfaced instead of being treated as data corruption.

## Prerequisites

- Flutter SDK with Dart 3.12.2 or newer in the supported `^3.12.2` range
- Android SDK and an available emulator/device for `flutter run`
- A configured Android toolchain for APK builds (`flutter doctor` is useful for
  checking local setup)

## Develop and verify

From the repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --debug
```

The debug APK is written to
`build/app/outputs/flutter-apk/app-debug.apk`.

## Not included yet

Later phases cover expanded/generated level content and independent solver
validation, hints, active life/failure mechanics, sound and vibration effects,
Firebase services, and consent-aware advertising/monetization. Lives and the
sound/vibration preferences are persisted now, but they are intentionally
inactive in this playable core.
