# Tiny Browser - Flutter Web Browser

A lightweight, feature-rich web browser built with Flutter. Supports background media playback and Picture-in-Picture mode for Android.

## Features

- 🌐 Full-featured web browser with URL navigation
- 📱 Bookmark management
- 📜 Browsing history
- 🔍 Search functionality (DuckDuckGo)
- 🎭 Custom user agent selection
- 🎵 **Background media playback** - Continue playing videos/audio when app is minimized
- 📺 **Picture-in-Picture (PiP) mode** - Watch videos in a floating window (Android 8.0+)
- 🎮 **Media controls** - Play/pause controls for detected media
- 📱 Material Design 3 UI

## Screenshots

_(Add screenshots here if available)_

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / Xcode (for mobile development)
- Android SDK (API 21+ for Android)
- Android 8.0+ for Picture-in-Picture support

### Installation

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/browserflut-main.git
cd browserflut-main
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Usage

### Navigation
- Enter a URL in the address bar and press Enter or tap the Go button
- Use Back/Forward buttons to navigate history
- Tap Home button to return to home page
- Tap Reload to refresh the current page

### Bookmarks
- Tap the star icon to bookmark/unbookmark the current page
- Access bookmarks from the menu (⋮)
- Clear bookmarks from the menu

### Media Playback
- When media is detected on a page, media controls appear automatically
- Tap Play/Pause button to control playback
- Tap Picture-in-Picture button to enter PiP mode (Android only)
- Media continues playing in background when app is minimized

### Picture-in-Picture (Android)
- Requires Android 8.0 (API 26) or higher
- Tap PiP button in the app bar or media bar when media is playing
- Video continues playing in a floating window
- Supports YouTube and other HTML5 video players

### User Agent
- Access menu (⋮) > Customize User Agent
- Choose from:
  - Default (device default)
  - Chrome Desktop
  - Safari on iPhone

## Technical Details

### Background Media Playback
The app uses JavaScript injection to detect and control media elements on web pages. It supports:
- Standard HTML5 `<video>` and `<audio>` elements
- YouTube video player API
- Automatic media state detection
- Real-time playback state monitoring

### Picture-in-Picture
- Implemented using Android's `PictureInPictureParams` API
- Requires `supportsPictureInPicture` and `resizeableActivity` in AndroidManifest
- Method channel communication between Flutter and native Android code

### Permissions
The app requires the following Android permissions:
- `INTERNET` - Web browsing
- `WAKE_LOCK` - Keep device awake during playback
- `FOREGROUND_SERVICE` - Background media playback
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK` - Media playback service

## Project Structure

```
lib/
  └── main.dart          # Main application code
android/
  └── app/
      └── src/
          └── main/
              ├── AndroidManifest.xml
              └── kotlin/
                  └── MainActivity.kt    # Native Android PiP implementation
```

## Dependencies

- `webview_flutter: 4.13.0` - WebView widget
- `webview_flutter_web: ^0.2.3` - Web platform support
- `flutter_lints: ^5.0.0` - Linting rules

## Platform Support

- ✅ Android (8.0+ for full features)
- ✅ iOS (basic browsing, no PiP)
- ✅ Web (basic browsing)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the MIT License.

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Uses [webview_flutter](https://pub.dev/packages/webview_flutter) for web rendering
