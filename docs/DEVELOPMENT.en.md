[Today](../README.en.md) · [Русский](DEVELOPMENT.md) · **English**

# Developing Today

Build, test, and architecture instructions for the native Mac and Windows apps.
Run commands from the TodayBar repository root unless stated otherwise.
For normal installation, use the [ready-to-run downloads](../README.en.md#download).

## macOS

Use a Mac with Xcode or Xcode Command Line Tools installed:

```bash
git clone https://github.com/IwanBelenko/TodayBar.git
cd TodayBar
./scripts/build-app.sh
```

The result is `dist/Today.app`: a universal Intel + Apple Silicon app with an ad-hoc signature.
Tests require Swift 6 or later; the test framework's minimum OS can be newer than the
app's macOS 13 deployment target.

```bash
./scripts/test.sh
TODAYBAR_TEST_LANGUAGE=ru TODAYBAR_SNAPSHOT_DIR="$PWD/.build/ui-previews/ru" ./scripts/test.sh
TODAYBAR_TEST_LANGUAGE=en TODAYBAR_SNAPSHOT_DIR="$PWD/.build/ui-previews/en" ./scripts/test.sh
```

Tests cover older JSON files, persistence, priorities and ordering, category-scoped
search and history, language selection, data compatibility, and Enter handling. The language
override above is test-only and is excluded from release builds. Optional UI snapshots use sample data and
the real rounded `TodayPanel`, with transparent-corner checks. Tests do not read personal tasks.

## Windows

Install [.NET SDK 10](https://dotnet.microsoft.com/download/dotnet/10.0), then run from
the repository root in PowerShell:

```powershell
dotnet run --project Windows/Today.Core.Tests
dotnet run --project Windows/Today.Windows
./scripts/build-windows.ps1 -Runtime win-x64
./scripts/build-windows.ps1 -Runtime win-arm64
```

Self-contained executables are written to `dist/Today-win-x64/Today.exe` and
`dist/Today-win-arm64/Today.exe`. The `--startup` option starts quietly in the tray.
To cross-build on Mac/Linux:

```bash
dotnet publish Windows/Today.Windows -c Release -r win-x64 --self-contained true \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:PublishTrimmed=false \
  -o dist/Today-win-x64
```

Windows Desktop reference/runtime packs are downloaded from NuGet. There are no
third-party package dependencies. Cross-building does not prove that the app runs on Windows.

On Windows, `Today.exe --smoke-test <folder>` checks click-only tray event bindings,
the native interface, search, history, menus, task entry, clipboard, and the calendar.
It checks Russian and English and saves light/dark screenshots in `ru-RU` and `en-US`
subfolders using temporary data, without changing startup
settings, displaying a tray icon, or accessing personal tasks.

[GitHub Actions](https://github.com/IwanBelenko/TodayBar/actions/workflows/build.yml)
runs checks on Windows x64 and builds both x64 and ARM64 executables. Manual checks of
the actual system tray, reminders, startup, different DPI settings, and physical ARM64
hardware are separate; screenshots and a successful build do not replace them.

Keep README screenshots in versioned folders under `docs/screenshots/`. Windows
snapshots come from the successful build's `Today-Windows-previews` artifact.

README GIFs use captures of the production `TodayPanel` with in-memory sample tasks.
They are scripted UI demonstrations, not desktop recordings; personal data is never loaded.
The cursor and short click rings are added during GIF assembly, with motion at 20 fps.
The scenario checks Add, Clear search, and Complete clicks in the test window,
plus sorting and search. Priority is changed programmatically: a caption shows
the menu path, without recording the open menu. Enter has a separate test.
To regenerate with standard macOS and Swift tools:

```bash
TODAYBAR_TEST_LANGUAGE=ru TODAYBAR_DEMO_DIR="$PWD/.build/demo/ru" ./scripts/test.sh --filter recordReadmeDemo
swift scripts/make-demo.swift .build/demo/ru docs/demos/v1.6.1/today-ru.gif
TODAYBAR_TEST_LANGUAGE=en TODAYBAR_DEMO_DIR="$PWD/.build/demo/en" ./scripts/test.sh --filter recordReadmeDemo
swift scripts/make-demo.swift .build/demo/en docs/demos/v1.6.1/today-en.gif
```

## Architecture

```text
AppSources/TodayBar
├── App             # lifecycle and macOS menu-bar integration
├── Data            # local JSON storage
├── Domain          # task models
└── Presentation    # SwiftUI interface and view state

Windows
├── Today.Core          # models, filters, sorting, atomic JSON storage
├── Today.Core.Tests    # portable tests with temporary data
└── Today.Windows       # WPF, tray, calendar, startup, notifications
```

The platforms share a compatible data format, not a server or a cross-language bridge.
Development artifacts are available from successful Actions runs (`Today-universal`,
`Today-windows-x64`, `Today-windows-arm64`). They require GitHub sign-in and expire;
use the [release downloads](../README.en.md#download) for normal installation.

[Back to Today](../README.en.md) · [User guide](GUIDE.en.md)
