## Flutter Chat App

Multi‑platform chat UI powered by a FastAPI backend with streaming (SSE) and OpenAI Responses API.

### Prerequisites
- Flutter SDK installed (stable)
- Dart SDK (bundled with Flutter)
- Android Studio or Xcode if targeting mobile
- A running backend (see `backend/README.md`) or a deployed URL

### Configure API base URL
The app reads the backend URL from a compile‑time define `API_BASE_URL`.

- Local default fallbacks exist:
  - Android emulator: `http://10.0.2.2:8000`
  - Others: `http://127.0.0.1:8000`

Override at run/build time:
```bash
flutter run --dart-define=API_BASE_URL=https://your-backend-url
```

### Run on Web
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

### Run on Android emulator/device
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### Run on Windows (desktop)
```bash
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

### Build release (examples)
```bash
# Web
flutter build web --dart-define=API_BASE_URL=https://your-backend-url

# Android APK (debug signing)
flutter build apk --dart-define=API_BASE_URL=https://your-backend-url
```

### Features
- Streaming chat responses (SSE)
- Weather and holidays helper intents
- One‑tap image provider link generation (explicit prompts only)
- ChatGPT‑style assistant action buttons (copy, like/dislike, speak, regenerate, share)

### Troubleshooting
- If the app can’t connect to backend, verify `API_BASE_URL` and CORS on the server
- For Android, always use `10.0.2.2` to reach `localhost` on your machine
- Run `flutter clean && flutter pub get` if you see stale build artifacts

