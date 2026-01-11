# GehChat

Flutter IRC chat client for Android with Material Design 3.

## Features

- 📱 IRC connection with manual connect/disconnect
- 💬 Main channel chat and private messages
- 🔔 Push notifications for messages
- 💾 Connection settings persistence
- 🎨 Material Design 3 UI with dark theme support
- 📲 Clean foreground-only operation (no background services)

## Architecture

- **Frontend**: Flutter (Dart)
- **State Management**: Provider
- **Notifications**: flutter_local_notifications
- **Persistence**: shared_preferences

## Getting Started

### Prerequisites

- Flutter SDK 3.10.7 or higher
- Android SDK for Android builds
- Dart 3.0.0 or higher

### Installation

1. Clone the repository
```bash
git clone https://github.com/sebszczec/GehChat.git
cd GehChat/Frontend/geh_chat_frontend
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
flutter run
```

## Usage

1. Launch the app
2. Enter IRC server details (server, port, channel, nickname)
3. Click "Connect"
4. Start chatting!

## Project Structure

```
GehChat/
├── Frontend/
│   └── geh_chat_frontend/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── models/
│       │   │   └── chat_state.dart
│       │   ├── screens/
│       │   │   ├── connection_screen.dart
│       │   │   ├── main_chat_screen.dart
│       │   │   └── private_chat_screen.dart
│       │   └── services/
│       │       ├── irc_service.dart
│       │       ├── notification_service.dart
│       │       └── connection_settings_service.dart
│       └── android/
└── Backend/ (planned)
```

## License

This project is open source and available under the MIT License.
