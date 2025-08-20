# UpNext — System Requirements and Setup

This file lists what you need installed to run the local stack (MongoDB + Go API) and the Flutter app, plus quick checks and links.

## Target OS
- Windows 10/11 (x64) with virtualization enabled

## Required software
- Docker Desktop (WSL 2 backend)
  - Install: https://docs.docker.com/desktop/install/windows-install/
  - Requires Windows Subsystem for Linux 2 (WSL 2)
- Windows Subsystem for Linux 2 (WSL 2)
  - Install: https://learn.microsoft.com/windows/wsl/install
- Git (recommended)
  - Install: https://git-scm.com/download/win

## Optional (but recommended)
- Flutter SDK (to run the app locally)
  - Install: https://docs.flutter.dev/get-started/install/windows
  - Recommended: stable channel, Flutter 3.22+ (Dart 3.4+)
  - Enable web: `flutter config --enable-web`
  - Chrome (for running on web): https://www.google.com/chrome/
- Android Studio + SDK (only if running on Android emulator)
  - Install: https://developer.android.com/studio
- Go (only if you want to run the API without Docker)
  - Install: https://go.dev/dl/ (Go 1.22+)

## Minimum versions
- Docker Desktop: recent stable (4.33+ recommended)
- WSL 2 enabled
- Flutter (if used): 3.22+
- Go (if used): 1.22+

## Quick setup steps (Windows PowerShell)
1) Ensure WSL 2 is enabled
```powershell
wsl --install
wsl --set-default-version 2
wsl --update
```

2) Install and start Docker Desktop (WSL 2 backend)
- Open Docker Desktop and wait until it shows "Running".

3) Start the backend (MongoDB + API)
```powershell
cd C:\Users\corba\Documents\UpNext
# build API image and start services
docker compose up -d
# health check
curl http://localhost:8080/healthz
```

4) Run the Flutter app (Chrome web)
```powershell
cd C:\Users\corba\Documents\UpNext\flutter_app
flutter --version
flutter doctor
flutter pub get
flutter config --enable-web
flutter run -d chrome
```
- The app calls the API at `http://localhost:8080` by default.
- Android emulator: use `--dart-define=API_BASE=http://10.0.2.2:8080`.

## Troubleshooting
- Docker "version is obsolete" warning: the `version` key in docker-compose.yml can be removed; it’s harmless.
- Rebuild API if code changes:
```powershell
cd C:\Users\corba\Documents\UpNext
docker compose build api ; docker compose up -d
```
- Reset DB (removes data and re-seeds):
```powershell
docker compose down -v ; docker compose up -d
```
- API not healthy:
```powershell
docker logs upnext-api --tail 200
```
- Flutter not found: reopen PowerShell after adding Flutter to PATH, or restart.

## Notes
- You do not need Go installed if you run the API in Docker.
- You do not need local MongoDB; Docker Compose provides it and seeds sample data.
