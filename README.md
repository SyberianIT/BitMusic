# BitMusic

Приложение для поиска и скачивания музыки с YouTube.  
Платформы: **Android · iOS · Linux · Windows**.

---

## Возможности

| Функция | Описание |
|---------|----------|
| Поиск | По названию трека, имени исполнителя или строкам из текста (через YouTube) |
| Скачивание | Аудиодорожка лучшего качества (AAC/M4A на мобильных; MP3 192 kbps на ПК при наличии ffmpeg) |
| Прогресс | Индикатор загрузки прямо в карточке трека |
| Плеер | Встроенный офлайн-плеер для скачанных треков |
| Темы | Material Design 3, авто светлая/тёмная по системе |
| Адаптив | `BottomNavigationBar` на телефонах, `NavigationRail` на планшетах и ПК |

---

## Структура проекта

```
lib/
├── main.dart
├── app.dart
├── models/
│   └── track.dart
├── services/
│   ├── youtube_service.dart
│   ├── download_service.dart
│   ├── player_service.dart
│   └── database_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── search_screen.dart
│   └── library_screen.dart
└── widgets/
    ├── track_card.dart
    ├── library_track_card.dart
    ├── download_dialog.dart
    └── mini_player.dart
```

---

## Быстрый старт

### Требования

- Flutter SDK >= 3.19 (stable)
- Dart >= 3.3
- Linux: `sudo apt install ffmpeg libgtk-3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`
- Windows: установите [ffmpeg](https://ffmpeg.org/download.html) и добавьте в PATH
- Android: minSdkVersion 21 (Android 5.0+)

### 1. Клонирование и генерация платформенного кода

```bash
git clone https://github.com/syberianit/bitmusic.git
cd bitmusic

# Генерация недостающего бойлерплейта (ios/, windows/ и т.д.)
flutter create --org com.syberianit --project-name bitmusic \
               --platforms android,ios,linux,windows \
               --no-overwrite .

flutter pub get
```

> `--no-overwrite` сохраняет все уже созданные файлы.

### 2. Запуск в режиме отладки

```bash
flutter run                    # текущая платформа
flutter run -d linux           # Linux desktop
flutter run -d windows         # Windows desktop
flutter run -d android         # Android
```

---

## Сборка релизов

### Android APK

```bash
flutter build apk --release --split-per-abi
# APK: build/app/outputs/flutter-apk/

# Google Play App Bundle:
flutter build appbundle --release
```

### iOS (требуется macOS)

```bash
flutter build ios --release --no-codesign
# Откройте ios/Runner.xcworkspace в Xcode для подписи и архивации
```

### Windows EXE / MSIX

```bash
flutter build windows --release
# EXE: build/windows/x64/runner/Release/

# MSIX-пакет (нужен пакет msix):
dart pub global activate msix
flutter pub run msix:create
```

### Linux (.deb)

**Автоматический скрипт:**

```bash
chmod +x scripts/build_deb.sh
./scripts/build_deb.sh
# Результат: bitmusic_1.0.0-1_amd64.deb
# Установка: sudo dpkg -i bitmusic_1.0.0-1_amd64.deb && sudo apt-get install -f
```

**Ручная сборка:**

```bash
flutter build linux --release
sudo cp -r build/linux/x64/release/bundle /opt/bitmusic
sudo ln -sf /opt/bitmusic/bitmusic /usr/local/bin/bitmusic
```

---

## Зависимости

| Пакет | Версия | Назначение |
|-------|--------|------------|
| `youtube_explode_dart` | ^2.2.1 | Поиск YouTube, аудиопотоки |
| `path_provider` | ^2.1.3 | Пути к файловой системе |
| `permission_handler` | ^11.3.1 | Разрешения Android/iOS |
| `dio` | ^5.7.0 | HTTP |
| `audioplayers` | ^6.1.0 | Воспроизведение аудио |
| `cached_network_image` | ^3.4.1 | Кэш обложек |
| `hive` + `hive_flutter` | ^2.2.3 / ^1.1.0 | Локальное хранилище |
| `provider` | ^6.1.2 | State management |

---

## MP3-конвертация

| Платформа | Метод |
|-----------|-------|
| Linux / Windows / macOS | `Process.run('ffmpeg', [...])` — системный ffmpeg; если не установлен, файл сохраняется как `.m4a` или `.webm` |
| Android / iOS | Файл сохраняется как `.m4a` (AAC). Для MP3 добавьте `ffmpeg_kit_flutter_new: ^6.0.3` |

### Добавление ffmpeg_kit для мобильных (опционально)

```yaml
# pubspec.yaml
dependencies:
  ffmpeg_kit_flutter_new: ^6.0.3
```

```dart
// download_service.dart — замените _convertToMp3():
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

Future<bool> _convertToMp3(String input, String output) async {
  final session = await FFmpegKit.execute(
    '-i "$input" -codec:a libmp3lame -b:a 192k -y "$output"');
  final rc = await session.getReturnCode();
  return ReturnCode.isSuccess(rc);
}
```

---

## Разрешения Android

| Разрешение | Нужно для |
|-----------|-----------|
| `INTERNET` | Поиск и скачивание |
| `READ_EXTERNAL_STORAGE` | Чтение файлов (Android <= 9) |
| `WRITE_EXTERNAL_STORAGE` | Запись в /Music (Android <= 9) |
| `READ_MEDIA_AUDIO` | Чтение аудио (Android 13+) |
| `MANAGE_EXTERNAL_STORAGE` | Запись в /Music (Android 10+) |

---

## Лицензия

[MIT](LICENSE)