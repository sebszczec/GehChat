# GehChat Backend

Backend server dla aplikacji GehChat - IRC client.

## Technologie

- **Python 3.11+**
- **FastAPI** - Nowoczesny framework web
- **Uvicorn** - ASGI server
- **WebSockets** - Komunikacja real-time

## Instalacja

```bash
# Utwórz środowisko wirtualne
python -m venv venv

# Aktywuj środowisko
# Windows
.\venv\Scripts\activate
# Linux/Mac
source venv/bin/activate

# Zainstaluj zależności
pip install -r requirements.txt
```

## Uruchomienie

```bash
# Development mode z auto-reload
python main.py

# Lub używając uvicorn bezpośrednio
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Server będzie dostępny pod adresem: `http://localhost:8000`

## Endpointy

### REST API

- `GET /` - Health check
- `GET /api/health` - Detailed health status

### WebSocket

- `WS /ws` - WebSocket endpoint dla real-time komunikacji

## Dokumentacja API

Po uruchomieniu serwera, dokumentacja Swagger UI dostępna jest pod:
- http://localhost:8000/docs
- http://localhost:8000/redoc

## Struktura Projektu

```
Backend/
├── main.py              # Główny plik aplikacji
├── requirements.txt     # Zależności Python
├── .env                 # Zmienne środowiskowe (nie commitować)
├── .gitignore          # Git ignore rules
└── README.md           # Ten plik
```

## Rozwój

### Planowane Funkcjonalności

- [ ] IRC Bridge - połączenia z serwerami IRC
- [ ] Autentykacja użytkowników
- [ ] Persystencja wiadomości
- [ ] Historia czatu
- [ ] Multi-channel support
- [ ] File upload/download

## Licencja

MIT
