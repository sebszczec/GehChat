# WebSocket Architecture Migration

## Overview
GehChat has been migrated from direct IRC connection to a WebSocket-based architecture where the backend acts as an IRC bridge.

## Architecture Changes

### Before (Direct Connection)
```
[Flutter Client] <--TCP Socket--> [IRC Server (slaugh.pl:6667)]
```

### After (WebSocket Bridge)
```
[Flutter Client] <--WebSocket--> [Backend (localhost:8000)] <--TCP Socket--> [IRC Server (slaugh.pl:6667)]
```

## Benefits

1. **Web Platform Support** ✅
   - WebSocket works on all platforms including Web
   - No more "IRC not supported in browser" limitation

2. **Enhanced Security** 🔒
   - Backend can implement authentication
   - Rate limiting and validation
   - Single point for security policies

3. **Better Scalability** 📈
   - Multiple clients can share IRC connections
   - Backend can manage connection pooling
   - Easier to add features like message history

4. **Unified Protocol** 🔄
   - All platforms use the same WebSocket protocol
   - Consistent behavior across mobile, desktop, and web

## Backend Configuration

**Default IRC Server Settings** (in backend):
- Server: `slaugh.pl`
- Port: `6667`
- Channel: `#vorest`

## Client Configuration

**Default Backend Connection** (in frontend):
- Server: `localhost`
- Port: `8000`
- Protocol: `WebSocket (ws://)`

## WebSocket Message Protocol

### Client → Backend

#### Connect to IRC
```json
{
  "type": "connect",
  "server": "slaugh.pl",
  "port": 6667,
  "channel": "#vorest",
  "nickname": "MyNick"
}
```

#### Send Message
```json
{
  "type": "message",
  "target": "#vorest",
  "content": "Hello World!"
}
```

#### Disconnect
```json
{
  "type": "disconnect"
}
```

### Backend → Client

#### System Message
```json
{
  "type": "system",
  "content": "Connected to IRC server"
}
```

#### IRC Message
```json
{
  "type": "message",
  "sender": "JohnDoe",
  "target": "#vorest",
  "content": "Hello!",
  "is_private": false
}
```

#### User List
```json
{
  "type": "users",
  "users": ["user1", "user2", "user3"]
}
```

#### User Join
```json
{
  "type": "join",
  "user": "NewUser"
}
```

#### User Part/Quit
```json
{
  "type": "part",
  "user": "OldUser"
}
```

## Files Changed

### Backend
- `Backend/main.py` - Complete IRC bridge implementation
- `Backend/requirements.txt` - Added `irc==20.5.0`

### Frontend
- `Frontend/geh_chat_frontend/lib/services/websocket_irc_service.dart` - New WebSocket-based service
- `Frontend/geh_chat_frontend/lib/main.dart` - Updated to use WebSocket service
- `Frontend/geh_chat_frontend/lib/models/chat_state.dart` - Updated import
- `Frontend/geh_chat_frontend/lib/screens/connection_screen.dart` - Updated default connection (localhost:8000), removed Web platform block
- `Frontend/geh_chat_frontend/pubspec.yaml` - Added `web_socket_channel: ^3.0.1`

## Running the Application

### Start Backend
```bash
cd Backend
python main.py
```
Backend will listen on: `http://localhost:8000`

### Start Frontend
```bash
cd Frontend/geh_chat_frontend
flutter run -d windows  # or chrome for web!
```

### Or Use VS Code Tasks
`Ctrl+Shift+P` → `Tasks: Run Task` → `Start Backend & Frontend`

## Web Support 🌐

The application now **fully supports Web platform**! 

To run on Web:
```bash
cd Frontend/geh_chat_frontend
flutter run -d chrome
```

No more restrictions - WebSocket works everywhere! 🎉

## Testing

1. Start backend: `python Backend/main.py`
2. Backend should show: `Uvicorn running on http://0.0.0.0:8000`
3. Start frontend and connect
4. Default settings will connect to localhost:8000
5. Backend will bridge to IRC server automatically

## Future Enhancements

- [ ] User authentication
- [ ] Message history persistence
- [ ] Multiple IRC networks support
- [ ] File upload/download
- [ ] End-to-end encryption
- [ ] Typing indicators
- [ ] Read receipts
