# GehChat

Kompletna aplikacja czatu IRC z backendem Python i frontendem Flutter.

## 🏗️ Architektura

```
GehChat/
├── Backend/              # Python FastAPI server - IRC Bridge
│   ├── main.py          # Główny plik serwera - IRC Bridge
│   ├── config.py        # Konfiguracja (IRC, Backend)
│   ├── requirements.txt # Zależności Python
│   ├── .env.example     # Przykładowa konfiguracja
│   └── venv/            # Środowisko wirtualne
└── Frontend/            # Flutter aplikacja
    └── geh_chat_frontend/
        ├── lib/         # Kod źródłowy Dart
        │   ├── config/  # Konfiguracja (backend_config.dart)
        │   ├── services/ # Usługi (WebSocket IRC service)
        │   └── ...
        ├── android/     # Konfiguracja Android
        ├── ios/         # Konfiguracja iOS
        └── windows/     # Konfiguracja Windows
```

### Przepływ komunikacji

```
Client (Flutter) <--> WebSocket <--> Backend (Python) <--> IRC Server
     ws://localhost:8000/ws            Socket              slaugh.pl:6667
```

Backend działa jako **IRC Bridge**, przekazując wiadomości między klientami WebSocket a serwerem IRC.

## 🚀 Szybki Start

### Wymagania

- Python 3.11 lub nowszy
- Flutter SDK 3.0+
- Visual Studio Code (zalecane)

### Instalacja Zależności

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

### 🎯 Uruchamianie w VS Code

#### Opcja 1: Użyj Tasks (Zalecane)
1. Otwórz paletę komend: `Ctrl+Shift+P`
2. Wpisz: `Tasks: Run Task`
3. Wybierz: **"Start Backend & Frontend"**

To uruchomi oba serwery jednocześnie w osobnych terminalach!

#### Opcja 2: Użyj Debuggera
1. Przejdź do zakładki Run/Debug (`Ctrl+Shift+D`)
2. Wybierz z dropdown: **"🚀 Full Stack: Backend + Frontend"**
3. Kliknij zielony przycisk Play (F5)

To uruchomi oba projekty w trybie debug!

#### Opcja 3: Ręcznie

**Terminal 1 - Backend:**
```bash
cd Backend
python main.py
```
Server będzie dostępny pod: http://localhost:8000

**Terminal 2 - Frontend:**
```bash
cd Frontend/geh_chat_frontend
flutter run -d windows
```

### 📡 Dostęp do API

- **Backend API**: http://localhost:8000
- **API Docs (Swagger)**: http://localhost:8000/docs
- **WebSocket**: ws://localhost:8000/ws

## 📚 Dokumentacja

- [Backend README](Backend/README.md) - Dokumentacja serwera Python
- [Frontend README](Frontend/geh_chat_frontend/README.md) - Dokumentacja aplikacji Flutter
- [Communication Design](GehChat_Communication_Design.html) - Dokumentacja komunikacji klient-serwer

## 🛠️ Dostępne Komendy VS Code

### Tasks (Ctrl+Shift+P → Tasks: Run Task)
- **Start Backend & Frontend** - Uruchom całą aplikację
- **Start Backend (Python)** - Tylko backend
- **Start Frontend (Flutter)** - Tylko frontend
- **Install All Dependencies** - Zainstaluj wszystkie zależności
- **Install Backend Dependencies** - Tylko zależności Python
- **Install Frontend Dependencies** - Tylko zależności Flutter

### Launch Configurations (F5)
- **🚀 Full Stack: Backend + Frontend** - Debug obu aplikacji
- **Python: Backend Server** - Debug tylko backend
- **geh_chat_frontend** - Debug tylko frontend

## 🔧 Konfiguracja

### Backend Configuration

Backend używa zmiennych środowiskowych do konfiguracji. Skopiuj `.env.example` do `.env` w katalogu Backend:

```bash
cd Backend
cp .env.example .env  # Linux/Mac
copy .env.example .env  # Windows
```

Dostosuj wartości w `.env`:
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

Frontend ma wbudowaną konfigurację w `lib/config/backend_config.dart`:
- Domyślny adres backendu: `127.0.0.1` (loopback IP)
- Domyślny port backendu: `8000`
- WebSocket URL: `ws://127.0.0.1:8000/ws`

Podczas łączenia, użytkownik podaje:
- **Backend Server** - adres serwera backendu (domyślnie 127.0.0.1, można zmienić na dowolny IP lub domenę)
- **Backend Port** - port backendu (domyślnie 8000)
- **Nickname** - pseudonim użytkownika

Kanał IRC jest automatycznie pobierany z backendu przez endpoint `/api/irc-config`.
Użytkownik nie musi znać szczegółów konfiguracji IRC - wszystko jest zarządzane przez backend.

## 📦 Technologie

### Backend
- **FastAPI** - Nowoczesny framework web
- **Uvicorn** - ASGI server
- **WebSockets** - Real-time komunikacja z klientami
- **Socket** - Bezpośrednie połączenie IRC
- **Python 3.11+**
- **Pydantic** - Walidacja i konfiguracja

### Frontend
- **Flutter** - Cross-platform UI framework
- **Dart** - Język programowania
- **Provider** - State management
- **WebSocket** - Komunikacja z backendem
- **web_socket_channel** - WebSocket dla Flutter

## 🤝 Wkład

Projekt jest otwarty na wkład społeczności. Pull requesty są mile widziane!

## 📄 Licencja

MIT License - szczegóły w pliku LICENSE

## 📞 Kontakt

Jeśli masz pytania lub sugestie, otwórz issue na GitHubie.

---

**Enjoy coding! 🎉**
