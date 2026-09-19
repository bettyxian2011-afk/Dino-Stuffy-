# Strata (`dino_app`)

Paleontology field companion — Flutter app. See repo docs:

- [App development plan](../docs/app-development-plan.md)
- [Iteration 7 Identify roadmap](../docs/iteration-7-identify-roadmap.md) (v0.1 → v1.0)

## Run (mock Identify)

No API key — uses canned `MockIdentifyRepository`:

```bash
flutter run
```

## Run (live Identify — Iteration 7 v0.1+)

Pass a Gemini API key at run time (**never commit the key**).

**Correct** (`NAME=value`):

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

**Wrong** (this leaves `GEMINI_API_KEY` empty and loads the mock repo):

```bash
flutter run --dart-define=your_key_here
```

Optional model override:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here --dart-define=GEMINI_MODEL=gemini-3.6-flash
```

On startup, debug console prints which adapter loaded:

- `StrataServices: GeminiIdentifyRepository (live vision)`
- `StrataServices: MockIdentifyRepository (no GEMINI_API_KEY)`

Vision uses the maintained [`googleai_dart`](https://pub.dev/packages/googleai_dart) client (replaces deprecated `google_generative_ai`, which breaks on Gemini 3.x responses).

Local convenience (gitignored): copy or create `run_live.local.ps1` with your key, then:

```powershell
.\run_live.local.ps1
.\run_live.local.ps1 -d emulator
```

## Tests

```bash
flutter test
```
