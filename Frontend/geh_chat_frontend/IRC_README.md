# IRC Chat Client

A modern IRC (Internet Relay Chat) client application built with Flutter.

## Features

- **Main Channel Chat**: Connect to IRC channels and chat with multiple users
- **Private Messaging**: Start private conversations with any user by clicking their name
- **User List**: View all connected users in the channel
- **Connection Status**: Real-time connection status indicator
- **Random Friendly Nicknames**: Automatically generates user-friendly nicknames
- **Modern UI**: Clean, Material Design 3 interface with light and dark themes
- **Internationalization Ready**: Built-in support for English and Polish languages

## Default Configuration

- **Server**: slaugh.pl
- **Port**: 6667
- **Channel**: #vorest
- **Nickname**: Randomly generated (e.g., HappyFox123, BraveDragon456)

## Project Structure

```
lib/
├── main.dart                          # Application entry point
├── l10n/
│   └── app_localizations.dart        # Localization strings (EN/PL)
├── models/
│   └── chat_state.dart               # Application state management
├── screens/
│   ├── main_chat_screen.dart         # Main channel chat interface
│   └── private_chat_screen.dart      # Private chat interface
└── services/
    └── irc_service.dart              # IRC protocol implementation
```

## How to Run

1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Run the application:
   ```bash
   flutter run
   ```

## Usage

### Starting the App
- The app automatically connects to the IRC server on launch
- A random friendly nickname is assigned
- You'll be joined to the #vorest channel

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

## Internationalization

The app currently supports:
- **English** (default)
- **Polish** (ready for use)

To change language, modify device settings or update the `supportedLocales` in [main.dart](lib/main.dart).

To add more languages:
1. Create a new class in [app_localizations.dart](lib/l10n/app_localizations.dart)
2. Extend `AppLocalizations`
3. Override all string getters with translations
4. Update `AppLocalizationsDelegate.load()` to handle the new locale
5. Add the locale to `supportedLocales` in [main.dart](lib/main.dart)

## Technical Details

### IRC Protocol Implementation
The [irc_service.dart](lib/services/irc_service.dart) handles:
- Socket connection management
- IRC handshake (NICK, USER, JOIN)
- PING/PONG keep-alive
- Message parsing (PRIVMSG)
- User list tracking (NAMES, JOIN, PART, QUIT, NICK)

### State Management
Uses the Provider pattern for reactive state management:
- `ChatState` manages messages, users, and connection status
- Automatic UI updates on state changes
- Separate streams for channel and private messages

### Architecture
- **Services**: Business logic and external communication
- **Models**: Data structures and state management
- **Screens**: UI components and user interaction
- **L10n**: Localization and internationalization

## Future Enhancements

Potential features to add:
- Multiple channel support
- Notification system for private messages
- Message history persistence
- Custom nickname selection
- Server/port configuration UI
- SSL/TLS support
- File sharing
- Emoji support
- User authentication (NickServ)
- Channel topics and modes
