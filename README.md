# GehChat

A complete IRC chat application with Python backend and Flutter frontend, featuring end-to-end encryption for private messages between Frontend users.

## 🏗️ Architecture

```
GehChat/
├── Backend/                    # Python FastAPI server - IRC Bridge
│   ├── main.py                # Main server file - FastAPI endpoints & WebSocket
│   ├── config.py              # Configuration (IRC, Backend)
│   ├── encryption_service.py  # AES-256-CBC encryption management
│   ├── irc_bridge.py          # IRC connection & message handling
│   ├── irc_parser.py          # IRC protocol parser
│   ├── message_handlers.py    # WebSocket message handlers
│   ├── requirements.txt       # Python dependencies
│   ├── pytest.ini             # Test configuration
│   ├── .env.example           # Example configuration
│   ├── tests/                 # Unit tests (67 tests)
│   └── venv/                  # Virtual environment
└── Frontend/                   # Flutter application
    └── geh_chat_frontend/
        ├── lib/               # Dart source code
        │   ├── config/        # Configuration (backend_config.dart)
        │   ├── l10n/          # Localization files
        │   ├── models/        # Data models (ChatState)
        │   ├── screens/       # UI screens
        │   │   ├── connection_screen.dart      # Connection settings
        │   │   ├── main_chat_screen.dart       # Main channel chat
        │   │   ├── private_chat_screen.dart    # Private messages
        │   │   └── system_messages_screen.dart # System messages
        │   ├── services/      # Services
        │   │   ├── irc_service.dart            # Main IRC service
        │   │   ├── irc_connection_manager.dart # WebSocket connection
        │   │   ├── irc_message_handler.dart    # Message processing
        │   │   ├── irc_translations.dart       # i18n (EN/PL)
        │   │   ├── encryption_service.dart     # AES encryption
        │   │   ├── notification_service.dart   # Push notifications
        │   │   └── ...
        │   ├── widgets/       # Reusable widgets
        │   │   ├── message_bubble.dart         # Chat bubbles
        │   │   ├── message_input.dart          # Input field
        │   │   ├── users_overlay.dart          # Users list
        │   │   └── ...
        │   └── main.dart      # App entry point
        ├── test/              # Unit tests (49 tests)
        ├── android/           # Android configuration
        ├── ios/               # iOS configuration
        └── windows/           # Windows configuration
```

### Communication Flow

```
Client (Flutter) <--> WebSocket <--> Backend (Python) <--> IRC Server
     ws://localhost:8000/ws            Socket              slaugh.pl:6667
```

Backend acts as an **IRC Bridge**, relaying messages between WebSocket clients and IRC servers.

## 💬 Message Communication Patterns

### 1️⃣ Frontend User → Main Channel

```
Frontend User (Alice)
        │
        │ (plain text)
        ↓
    Backend
        │
        ├─→ IRC Server
        │       └─→ All IRC Users
        │
        └─→ All other Frontend Users
                └─→ Via WebSocket
```

**Characteristics:**
- Frontend user sends message to main channel
- Backend broadcasts to all IRC users and all connected Frontend clients
- Messages are **NOT encrypted** (public channel)
- Used for general communication visible to everyone

---

### 2️⃣ Frontend User → IRC User (Private Message)

```
Frontend User (Alice)           IRC User (Bob)
        │                            ↑
        │ (plain text)               │ (plain text)
        ↓                            │
    Backend ←──────────────────────→ IRC Server
        
    (IRC PRIVMSG protocol)
```

**Characteristics:**
- Frontend user sends private message to IRC user
- Backend relays via IRC PRIVMSG protocol
- Messages are **NOT encrypted** (IRC doesn't support encryption)
- IRC user can only respond via IRC server (if connected)
- Messages are visible to IRC server administrator

---

### 3️⃣ Frontend User → Frontend User (Encrypted Private Message)

```
Frontend Alice                    Frontend Bob
        │                            │
        │ 1️⃣ Establish Session      │
        │   (on connection)          │
        │                            │
        ├────→ Backend ←────────────┤
        │   setup_encryption         │
        │                            │
        │ 2️⃣ Confirm Session Setup  │
        │   encryption_session_ready │
        ├────→ Backend ←────────────┤
        │                            │
        │ 3️⃣ Receive Session Key     │
        │        session_key          │
        ├────→ Backend ←────────────┤
        │                            │
        │ 4️⃣ Exchange Encrypted Msgs │
        │   (AES-256-CBC)            │
        ├───────────────────────────→│
        │                            │
```

**Characteristics:**
- **AES-256-CBC encryption** with per-session unique keys
- Backend manages **all encryption setup** (server-driven model)
- Session keys are **unique per user pair** (sorted names: `sorted([alice, bob])`)
- Private messages between Frontend users are **always encrypted**
- Encryption setup happens automatically **before first message** (prevents "first message problem")
- Both parties can immediately send/receive encrypted messages

---

## 🔐 Encryption Setup Protocol

### Initial State (Before Encryption)

```
Backend tracks:
- Frontend Users: [Alice, Bob, Charlie]
- Session Keys: {}
- Pending Sessions: {}
```

### Step 1: Frontend User Connects

```
Alice connects to Backend
         ↓
Backend registers Alice as Frontend user
         ↓
Backend identifies unencrypted users for Alice: [Bob, Charlie]
         ↓
Backend sends setup_encryption message:
{
  "type": "setup_encryption",
  "users": ["Bob", "Charlie"]
}
```

**Backend Code:**
```python
# After user registers
unencrypted_users = encryption_service.get_unencrypted_frontend_users(alice_nickname)
# unencrypted_users = ["Bob", "Charlie"]

send_to_frontend({
    "type": "setup_encryption",
    "users": unencrypted_users
})
```

---

### Step 2: Frontend Establishes Local Sessions

```
Alice receives setup_encryption message
         ↓
For each user in list (Bob, Charlie):
    1. Establish local session in EncryptionService
    2. Send encryption_session_ready confirmation to Backend
         ↓
Backend receives confirmations
```

**Frontend Code (Dart):**
```dart
case 'setup_encryption':
  final users = message['users'] as List<dynamic>?;
  if (users != null && _nickname != null) {
    for (final user in users) {
      final userName = user as String;
      // Step 1: Establish local session
      _encryptionService.establishSession(_nickname!, userName);
      
      // Step 2: Confirm to Backend
      _sendToBackend({
        'type': 'encryption_session_ready',
        'with': userName,
      });
    }
  }
  break;
```

---

### Step 3: Backend Verifies and Sends Session Key

```
Backend receives encryption_session_ready from Alice (with Bob)
         ↓
Backend establishes session: alice_bob (sorted names)
         ↓
Backend generates/retrieves session key
         ↓
Backend sends session_key message:
{
  "type": "session_key",
  "session": "alice_bob",
  "key": "<base64-encoded-key>"
}
         ↓
Alice injects key into local EncryptionService
```

**Backend Code (Python):**
```python
@app.websocket("/ws")
async def websocket_endpoint(websocket):
    # Handle encryption_session_ready
    elif message_type == "encryption_session_ready":
        from_user = self.nickname
        to_user = message['with']
        
        # Backend establishes session
        encryption_service.establish_session(from_user, to_user)
        
        # Get sorted session name
        users = sorted([from_user, to_user])
        session_key_name = f"{users[0]}_{users[1]}"
        
        # Retrieve the session key
        key = encryption_service.session_keys[session_key_name]
        
        # Send to Frontend
        await self.send_to_client({
            "type": "session_key",
            "session": session_key_name,
            "key": base64.b64encode(key).decode()
        })
```

---

### Step 4: Send Encrypted Message

```
Alice wants to send message to Bob
         ↓
Check: Does session alice_bob exist in EncryptionService?
         ├─ NO  → Block message (return early)
         └─ YES → Continue
                    ↓
                Encrypt message using AES-256-CBC
                    ↓
                Send encrypted payload to Backend
                    ↓
                Backend receives encrypted message
                    ↓
                Backend sends encrypted message to Bob
                    ↓
                Bob's Frontend EncryptionService decrypts
                    ↓
                Bob sees plain text message
```

**Frontend Code (Dart - sendMessage):**
```dart
void sendMessage(String target, String message) {
  if (_nickname == null) return;

  // For Frontend users - REQUIRE encryption
  final sessionKey = _getSessionKeyName(_nickname!, target);
  if (!_encryptionService.sessionKeys.containsKey(sessionKey)) {
    // Cannot send - session not ready (blocks silently)
    debugPrint('Session not ready for $target');
    return;
  }

  // Session exists - encrypt and send
  final encryptedMessage = _encryptionService.encryptMessage(
    _nickname!,
    target,
    message,
  );

  if (encryptedMessage != null) {
    _sendToBackend({
      'type': 'message',
      'target': target,
      'content': encryptedMessage,
      'is_encrypted': true,
    });
  }
}
```

---

## 🔑 Session Key Naming Convention

Both Backend and Frontend use **identical session key format** for consistency:

```
Session Key = sorted([user1, user2]) joined with underscore

Examples:
- alice + bob    → sort → [alice, bob]   → "alice_bob"
- bob + alice    → sort → [alice, bob]   → "alice_bob" (same!)
- charlie + alice → sort → [alice, charlie] → "alice_charlie"
```

**Why sorted?**
- Ensures **both directions** (alice→bob and bob→alice) use **same key**
- Prevents "two different keys for same pair" problem
- Works symmetrically: A can decrypt messages from B using same session key

---

## ✅ Encryption Guarantees

| Feature | Frontend↔Frontend | Frontend↔IRC |
|---------|------------------|--------------|
| Encryption | ✅ AES-256-CBC | ❌ Plain text |
| Session Keys | ✅ Pre-established | ❌ N/A |
| Backend Setup | ✅ Automatic & Pro-active | ❌ N/A |
| First Message Problem | ✅ Solved (setup before send) | ❌ N/A |
| Bidirectional | ✅ Always works | ❌ One-way (IRC only) |
| Private | ✅ End-to-end (Frontend controlled) | ⚠️ Visible to IRC admin |

---

## 📱 Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Windows | ✅ Full support | Primary development platform |
| Android | ✅ Full support | Tested on emulator & devices |
| Linux | ✅ Supported | Tested on Ubuntu |
| macOS | ⚠️ Untested | Should work |
| iOS | ⚠️ Untested | Should work |
| Web | ⚠️ Limited | WebSocket support varies |

---

## 🌍 Internationalization (i18n)

GehChat supports multiple languages with automatic detection based on device locale:

| Language | Code | Status |
|----------|------|--------|
| English | `en` | ✅ Full support |
| Polish | `pl` | ✅ Full support |

### Translated UI Elements
- Connection status messages
- User join/leave notifications (displayed in main chat)
- Error messages
- System notifications

### Join/Leave Notifications

User activity is displayed directly in the main channel with styled bubbles:
- **→ user joined the channel** (teal bubble)
- **← user left the channel** (orange bubble)  
- **← user quit** (orange bubble)

---

## 🚀 Quick Start

### Requirements

- Python 3.11 or newer
- Flutter SDK 3.0+
- Visual Studio Code (recommended)

### Install Dependencies

#### Backend (Python)
```bash
cd Backend
python -m venv venv
.\venv\Scripts\activate  # Windows
pip install -r requirements.txt
```

#### Frontend (Flutter)
```bash
cd Frontend/geh_chat_frontend
flutter pub get
```

### 🎯 Running in VS Code

#### Option 1: Use Tasks (Recommended)
1. Open command palette: `Ctrl+Shift+P`
2. Type: `Tasks: Run Task`
3. Select: **"Start Backend & Frontend"**

This will run both servers simultaneously in separate terminals!

#### Option 2: Use Debugger
1. Go to Run/Debug tab (`Ctrl+Shift+D`)
2. Select from dropdown: **"🚀 Full Stack: Backend + Frontend"**
3. Click the green Play button (F5)

This will run both projects in debug mode!

#### Option 3: Manual

**Terminal 1 - Backend:**
```bash
cd Backend
python main.py
```
Server will be available at: http://localhost:8000

**Terminal 2 - Frontend:**
```bash
cd Frontend/geh_chat_frontend
flutter run -d windows
```

### 📡 API Access

- **Backend API**: http://localhost:8000
- **API Docs (Swagger)**: http://localhost:8000/docs
- **WebSocket**: ws://localhost:8000/ws

## 📚 Documentation

- [Backend README](Backend/README.md) - Python server documentation
- [Frontend README](Frontend/geh_chat_frontend/README.md) - Flutter application documentation
- [Testing Guide](TESTING.md) - Detailed testing documentation
- [Quick Start Guide](QUICKSTART.md) - Getting started quickly
- [Android Setup](ANDROID_SETUP.md) - Android development setup
- [Communication Design](GehChat_Communication_Design.html) - Client-server communication documentation
- **Message Communication Patterns** (above) - Detailed flow diagrams for all communication types
- **Encryption Setup Protocol** (above) - Step-by-step encryption initialization guide

## 🛠️ Available VS Code Commands

### Tasks (Ctrl+Shift+P → Tasks: Run Task)
- **Start Backend & Frontend** - Run the entire application
- **Start Backend (Python)** - Backend only
- **Start Frontend (Flutter)** - Frontend only
- **Test All** - Run all tests (Backend + Frontend in parallel)
- **Test Backend (pytest)** - Run backend tests only
- **Test Frontend (Flutter)** - Run frontend tests only
- **Test All with Coverage** - Generate coverage reports
- **Install All Dependencies** - Install all dependencies
- **Install Backend Dependencies** - Python dependencies only
- **Install Frontend Dependencies** - Flutter dependencies only

### Launch Configurations (F5)
- **🚀 Full Stack: Backend + Frontend** - Debug both applications
- **Python: Backend Server** - Debug backend only
- **geh_chat_frontend** - Debug frontend only

## 🔧 Configuration

### Backend Configuration

Backend uses environment variables for configuration. Copy `.env.example` to `.env` in the Backend directory:

```bash
cd Backend
cp .env.example .env  # Linux/Mac
copy .env.example .env  # Windows
```

Customize values in `.env`:
```env
# Backend Server Configuration
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000

# IRC Server Configuration
IRC_SERVER=slaugh.pl
IRC_PORT=6667
IRC_CHANNEL=#vorest
```

### Frontend Configuration

Frontend has built-in configuration in `lib/config/backend_config.dart`:
- Default backend address: `127.0.0.1` (loopback IP)
- Default backend port: `8000`
- WebSocket URL: `ws://127.0.0.1:8000/ws`

When connecting, user provides:
- **Backend Server** - backend server address (default 127.0.0.1, can be changed to any IP or domain)
- **Backend Port** - backend port (default 8000)
- **Nickname** - user nickname

IRC channel is automatically fetched from backend via `/api/irc-config` endpoint.
User doesn't need to know IRC configuration details - everything is managed by the backend.

## 📦 Technologies

### Backend
- **FastAPI** - Modern web framework
- **Uvicorn** - ASGI server
- **WebSockets** - Real-time client communication
- **Socket** - Direct IRC connection
- **Python 3.11+**
- **Pydantic** - Validation and configuration
- **pycryptodome** - AES-256-CBC encryption
- **pytest** - Unit testing (67 tests)

### Frontend
- **Flutter 3.0+** - Cross-platform UI framework
- **Dart** - Programming language
- **Provider** - State management
- **web_socket_channel** - WebSocket for Flutter
- **encrypt** - AES encryption (Dart)
- **flutter_linkify** - URL detection in messages
- **connectivity_plus** - Network monitoring
- **flutter_local_notifications** - Push notifications
- **flutter_test** - Unit testing (49 tests)

---

## 🧪 Testing

### Run All Tests
```bash
# VS Code Task
Ctrl+Shift+P → Tasks: Run Task → Test All
```

### Backend Tests (67 tests)
```bash
cd Backend
.\venv\Scripts\activate
pytest tests/ -v
```

### Frontend Tests (49 tests)
```bash
cd Frontend/geh_chat_frontend
flutter test
```

### Test Coverage
```bash
# VS Code Task
Ctrl+Shift+P → Tasks: Run Task → Test All with Coverage
```

---

## 🤝 Contributing

The project is open to community contributions. Pull requests are welcome!

## 📄 License

MIT License - see LICENSE file for details

## 📞 Contact

If you have questions or suggestions, please open an issue on GitHub.

---

**Enjoy coding! 🎉**
