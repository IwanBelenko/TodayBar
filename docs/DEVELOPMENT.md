[Today](../README.md) · **Русский** · [English](DEVELOPMENT.en.md)

# Разработка Today

Сборка, тестирование и архитектура нативных приложений для Mac и Windows.
Все команды выполняются из корня репозитория TodayBar, если не указано иное.
Для обычной установки используйте [готовые приложения](../README.md#скачать).

## Сборка для macOS

Для сборки нужен Mac с актуальными Xcode Command Line Tools или Xcode.

```bash
git clone https://github.com/IwanBelenko/TodayBar.git
cd TodayBar
./scripts/build-app.sh
```

Готовое приложение появится в:

```text
dist/Today.app
```

Скрипт собирает единое приложение для Intel и Apple Silicon и подписывает его локальной ad-hoc подписью.

## Windows из исходников

Для разработки установите [.NET SDK 10](https://dotnet.microsoft.com/download/dotnet/10.0).
В PowerShell из корня репозитория:

```powershell
dotnet run --project Windows/Today.Core.Tests
dotnet run --project Windows/Today.Windows
./scripts/build-windows.ps1 -Runtime win-x64
./scripts/build-windows.ps1 -Runtime win-arm64
```

Готовые автономные приложения: `dist/Today-win-x64/Today.exe` и `dist/Today-win-arm64/Today.exe`.
Режим `--startup` открывает приложение сразу в трее, не показывая окно.
Для кросс-сборки на Mac/Linux с .NET SDK 10:

```bash
dotnet publish Windows/Today.Windows -c Release -r win-x64 --self-contained true \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:PublishTrimmed=false \
  -o dist/Today-win-x64
```

Кросс-сборка не проверяет работу окна на Windows. Приложение не требует сторонних пакетов;
Windows Desktop reference/runtime packs для сборки загружаются из NuGet.

## Проверки

Для тестов нужен Swift 6 или новее; минимальная версия системы для запуска тестов зависит от установленной библиотеки Swift Testing (в текущих Command Line Tools — macOS 14). Само приложение по-прежнему собирается для macOS 13+.

```bash
./scripts/test.sh
```

Тесты проверяют чтение старых файлов без приоритетов, сохранение новых полей, сортировку по огонькам и её обновление, поиск с фильтром разделов, порядок дней истории и обработку Enter только активным редактором. Проверяется выбор языка и сохранность текста и системных идентификаторов при переводе. Тесты используют временные данные и не читают личный список задач.

Windows: `dotnet run --project Windows/Today.Core.Tests` проверяет поиск, приоритеты,
сроки и переходы суток/DST, историю по разделам, совместимость JSON, сохранение и ошибки записи.
На Windows команда `Today.exe --smoke-test <папка>` запускает отдельный режим с временными
данными: проверяет, что наведение на значок не открывает окно, а клик открывает;
создаёт окно, проверяет фильтрацию, действия меню, добавление и копирование,
проверяет русский и английский интерфейсы, сохраняет снимки обеих тем и календаря
в подпапки `ru-RU` и `en-US`. Автозапуск и личные данные не затрагиваются.
GitHub Actions запускает эти проверки на Windows x64 и собирает оба варианта EXE.
Ручная проверка взаимодействия с системным треем, уведомлений, автозапуска, разных DPI и ARM64 остаётся
отдельной проверкой на соответствующем устройстве — снимки интерфейса её не заменяют.

Для дополнительных снимков интерфейса на тестовых данных:

```bash
TODAYBAR_TEST_LANGUAGE=ru TODAYBAR_SNAPSHOT_DIR="$PWD/.build/ui-previews/ru" ./scripts/test.sh
TODAYBAR_TEST_LANGUAGE=en TODAYBAR_SNAPSHOT_DIR="$PWD/.build/ui-previews/en" ./scripts/test.sh
```

В набор входят светлая и тёмная темы, найденная задача, пустая выдача и поиск по истории.
Снимки `today-light.png` и `today-dark.png` используют настоящее окно `TodayPanel`
с тем же оформлением, что и приложение; тест проверяет прозрачность скруглённых углов.
Подмена языка через `TODAYBAR_TEST_LANGUAGE` доступна только в отладочных тестовых сборках, не в релизе.
Для README снимки сохраняются в `docs/screenshots/v1.6.1/` с именами `macos-light.png` и `macos-dark.png`; английские — в подпапке `en/`.
Windows-снимки берутся из артефакта `Today-Windows-previews` успешной сборки GitHub Actions
и сохраняются в папке своей версии (`docs/screenshots/v1.6.1/`, английские — в `en/`).
При необходимости можно указать установленный SDK через переменную `SDKROOT`.

GIF для README собирается из кадров настоящего `TodayPanel` с задачами в памяти.
Это сценарная демонстрация состояний интерфейса, без записи рабочего стола и личных данных.
Курсор и короткие круги клика добавляются при сборке GIF; движение — 20 кадров/с.
Сценарий проверяет клики добавления, очистки поиска и выполнения в тестовом окне,
а также сортировку и поиск. Приоритет меняется программно: путь через меню указан
подписью, раскрытие меню не записывается. Enter проверяется отдельным тестом.
Для пересоздания нужны только стандартные инструменты macOS и Swift:

```bash
TODAYBAR_TEST_LANGUAGE=ru TODAYBAR_DEMO_DIR="$PWD/.build/demo/ru" ./scripts/test.sh --filter recordReadmeDemo
swift scripts/make-demo.swift .build/demo/ru docs/demos/v1.6.1/today-ru.gif
TODAYBAR_TEST_LANGUAGE=en TODAYBAR_DEMO_DIR="$PWD/.build/demo/en" ./scripts/test.sh --filter recordReadmeDemo
swift scripts/make-demo.swift .build/demo/en docs/demos/v1.6.1/today-en.gif
```

## Архитектура

Проект разделён на независимые слои:

```text
AppSources/TodayBar
├── App             # жизненный цикл и интеграция со строкой меню
├── Data            # локальное JSON-хранилище
├── Domain          # модель задачи
└── Presentation    # SwiftUI-интерфейс и состояние экрана
```

Windows-реализация находится рядом и не заменяет нативный Swift-код:

```text
Windows
├── Today.Core          # модели, фильтры, сортировка и атомарное JSON-хранилище
├── Today.Core.Tests    # переносимые проверки на временных данных
└── Today.Windows       # WPF, трей, календарь, автозапуск и уведомления
```

Связь платформ — совместимый формат данных и одинаковое поведение, без сервера и межъязыкового моста.

Промежуточные сборки доступны в [GitHub Actions](https://github.com/IwanBelenko/TodayBar/actions/workflows/build.yml).
В успешном запуске `main` откройте **Artifacts**: `Today-universal`, `Today-windows-x64` или
`Today-windows-arm64`. Для их скачивания нужен вход в GitHub, а срок хранения ограничен.
Для обычной установки используйте [постоянные ссылки на релиз](../README.md#скачать).

[На главную](../README.md) · [Руководство пользователя](GUIDE.md)
