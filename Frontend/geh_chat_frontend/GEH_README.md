# GehChat - Flutter IRC Client

A modern IRC (Internet Relay Chat) client application built with Flutter for Android.

## Features

- **Manual Connection**: Connect to any IRC server with custom settings
- **Connection Settings Persistence**: Server details are saved for convenience
- **Main Channel Chat**: Connect to IRC channels and chat with multiple users
- **Private Messaging**: Start private conversations with any user by clicking their name
- **User List**: View all connected users in the channel
- **Push Notifications**: Get notified of new messages with a single persistent notification
- **Connection Status**: Real-time connection status indicator
- **Modern UI**: Clean, Material Design 3 interface with dark theme support
- **Internationalization Ready**: Built-in support for English and Polish languages
- **Foreground-Only Operation**: App closes completely when killed (no background services)

## Architecture

- **State Management**: Provider pattern with global singleton IrcService
- **Notifications**: flutter_local_notifications for push notifications
- **Persistence**: shared_preferences for connection settings
- **Platform**: Android (Kotlin + Flutter)

## Connection Flow

1. Launch app → Connection screen with saved settings (if any)
2. Enter IRC server details:
   - Server address (e.g., slaugh.pl)
   - Port (e.g., 6667)
   - Channel (e.g., #vorest)
   - Nickname
3. Click "Connect" to manually connect
4. When connected, a single notification "GehChat: Connected to GehChat" appears
5. Chat in main channel or start private conversations
6. Swipe up to close → App closes completely, connection ends

## Project Structure

```
lib/
├── main.dart                              # Application entry point with global IrcService
├── l10n/
│   └── app_localizations.dart            # Localization strings (EN/PL)
├── models/
│   └── chat_state.dart                   # Application state management (Provider)
├── screens/
│   ├── connection_screen.dart            # Manual connection screen
│   ├── main_chat_screen.dart             # Main channel chat interface
│   └── private_chat_screen.dart          # Private chat interface with safe disposal
├── services/
│   ├── irc_service.dart                  # IRC protocol implementation
│   ├── notification_service.dart         # Push notifications management
│   ├── connection_settings_service.dart  # Settings persistence
│   └── foreground_service_manager.dart   # (Unused - legacy)
└── android/
    └── app/src/main/kotlin/.../
        ├── MainActivity.kt               # Android entry point
        ├── IrcForegroundService.kt       # (Disabled - legacy)
        └── RestartServiceReceiver.kt     # (Disabled - legacy)
```

## How to Run

1. Install Flutter dependencies:
   ```bash
   cd Frontend/geh_chat_frontend
   flutter pub get
   ```

2. Run the application:
   ```bash
   flutter run
   ```

## Usage

### Starting the App
- The app shows the connection screen on every launch
- If you previously connected, your settings are pre-filled
- Click "Connect" to manually establish connection

### Chatting
- Type your message in the text field at the bottom
- Press Send or hit Enter to send messages
- Messages appear in chat bubbles with timestamps

### Private Chats
1. Click the users icon in the top-right to view the user list
2. Click on any username
3. Select "Start Private Chat" from the bottom sheet
4. A new private chat screen opens
5. Access active private chats via the message icon (with badge count)

### UI Elements
- **Green dot**: Connected
- **Orange dot**: Connecting
- **Red error icon**: Connection error
- **Grey dot**: Disconnected
- **Users icon**: Toggle user list sidebar
- **Message icon with badge**: View/access private chats
- **Single Notification**: "GehChat: Connected to GehChat" when active

### Closing the App
- Swipe up to close the app
- Connection ends immediately
- Notification disappears
- No background operation
- App must be manually reopened and reconnected

## Internationalization

The app currently supports:
- **English** (default)
- **Polish** (ready for use)

To change language, modify device settings or update the `supportedLocales` in `main.dart`.

## Technical Details

### IRC Protocol Implementation
The `irc_service.dart` handles:
- Socket connection management
- IRC handshake (NICK, USER, JOIN)
- PING/PONG keep-alive
- Message parsing (PRIVMSG)
- User list tracking (NAMES, JOIN, PART, QUIT, NICK)
- Clean disconnect on app closure

### State Management
- Global singleton `IrcService` maintained throughout app lifecycle
- `ChatState` uses Provider for reactive UI updates
- Safe widget disposal with saved ChatState references

### Notifications
- Single persistent notification when connected
- Notification disappears on disconnect or app closure
- Android notification channel: "irc_connection"

### No Background Operation
- All background services disabled
- RestartServiceReceiver does not restart services
- IrcForegroundService not started automatically
- App behaves like a standard foreground app

## Recent Changes

- ✅ Removed auto-connect on app start
- ✅ Removed background operation and auto-reconnect
- ✅ Fixed widget disposal crash in private chat screen
- ✅ Fixed duplicate notifications (only one notification now)
- ✅ Disabled foreground service auto-start
- ✅ App closes completely when killed
