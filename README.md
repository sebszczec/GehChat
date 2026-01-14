# GehChat

A complete IRC chat application with Python backend and Flutter frontend.

## 🏗️ Architecture

```
GehChat/
├── Backend/              # Python FastAPI server - IRC Bridge
│   ├── main.py          # Main server file - IRC Bridge
│   ├── config.py        # Configuration (IRC, Backend)
│   ├── requirements.txt # Python dependencies
│   ├── .env.example     # Example configuration
│   └── venv/            # Virtual environment
└── Frontend/            # Flutter application
    └── geh_chat_frontend/
        ├── lib/         # Dart source code
        │   ├── config/  # Configuration (backend_config.dart)
        │   ├── services/ # Services (WebSocket IRC service)
        │   └── ...
        ├── android/     # Android configuration
        ├── ios/         # iOS configuration
        └── windows/     # Windows configuration
```

### Communication Flow

```
Client (Flutter) <--> WebSocket <--> Backend (Python) <--> IRC Server
     ws://localhost:8000/ws            Socket              slaugh.pl:6667
```

Backend acts as an **IRC Bridge**, relaying messages between WebSocket clients and IRC servers.

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
- [Communication Design](GehChat_Communication_Design.html) - Client-server communication documentation

## 🛠️ Available VS Code Commands

### Tasks (Ctrl+Shift+P → Tasks: Run Task)
- **Start Backend & Frontend** - Run the entire application
- **Start Backend (Python)** - Backend only
- **Start Frontend (Flutter)** - Frontend only
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

### Frontend
- **Flutter** - Cross-platform UI framework
- **Dart** - Programming language
- **Provider** - State management
- **WebSocket** - Backend communication
- **web_socket_channel** - WebSocket for Flutter

## 🤝 Contributing

The project is open to community contributions. Pull requests are welcome!

## 📄 License

MIT License - see LICENSE file for details

## 📞 Contact

If you have questions or suggestions, please open an issue on GitHub.

---

**Enjoy coding! 🎉**
