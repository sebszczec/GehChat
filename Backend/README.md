# GehChat Backend

Backend server dla aplikacji GehChat - IRC Bridge dla klientów WebSocket.

## Technologie

- **Python 3.11+**
- **FastAPI** - Nowoczesny framework web
- **Uvicorn** - ASGI server
- **WebSockets** - Komunikacja real-time z klientami
- **Socket** - Bezpośrednia komunikacja z serwerem IRC

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

## Konfiguracja

Backend używa zmiennych środowiskowych do konfiguracji. Skopiuj `.env.example` do `.env` i dostosuj wartości:

```bash
# Backend Server Configuration
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000

# IRC Server Configuration
IRC_SERVER=slaugh.pl
IRC_PORT=6667
IRC_CHANNEL=#vorest
```

Konfiguracja jest zarządzana przez `config.py`, który:
- Ładuje ustawienia IRC (serwer, port, kanał)
- Udostępnia endpoint `/api/irc-config` dla klientów
- Pozwala na łatwe zarządzanie konfiguracją przez zmienne środowiskowe

## Logowanie

Backend używa systemu logowania na trzech poziomach:
- **DEBUG** - Szczegółowe informacje diagnostyczne (domyślnie włączone)
  - Połączenia WebSocket i IRC
  - Wysyłane i odbierane wiadomości IRC
  - Przepływ danych między klientem a serwerem IRC
- **INFO** - Ogólne informacje o operacjach
  - Nowe połączenia
  - Zmiany stanu
- **WARNING** - Ostrzeżenia o potencjalnie problematycznych sytuacjach
  - Błędy połączeń
  - Nieoczekiwane rozłączenia
- **ERROR** - Błędy wymagające uwagi
  - Problemy z socketami
  - Błędy parsowania

Aby zmienić poziom logowania, edytuj `main.py`:
```python
logging.basicConfig(level=logging.DEBUG)  # DEBUG, INFO, WARNING, ERROR
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

- `GET /` - Health check i status
- `GET /api/health` - Detailed health status
- `GET /api/irc-config` - Pobierz konfigurację serwera IRC (dla klientów)

### WebSocket

- `WS /ws` - WebSocket endpoint dla IRC bridge komunikacji

## Dokumentacja API

Po uruchomieniu serwera, dokumentacja Swagger UI dostępna jest pod:
- http://localhost:8000/docs
- http://localhost:8000/redoc

## Struktura Projektu

```
Backend/
├── main.py              # Główny plik aplikacji - IRC Bridge
├── config.py            # Plik konfiguracyjny (IRC, Backend)
├── requirements.txt     # Zależności Python
├── .env                 # Zmienne środowiskowe (nie commitować)
├── .env.example         # Przykładowe zmienne środowiskowe
├── .gitignore          # Git ignore rules
└── README.md           # Ten plik
```

## Architektura

Backend działa jako **IRC Bridge**:

```
Client (Flutter) <--> WebSocket <--> Backend (Python) <--> IRC Server
```

1. Klient łączy się z backendem przez WebSocket
2. Backend przekazuje wiadomości do/z serwera IRC
3. Wspiera wiele jednoczesnych połączeń klientów

## Rozwój

### Zaimplementowane Funkcjonalności

- ✅ IRC Bridge - połączenie z serwerem IRC przez Socket
- ✅ WebSocket endpoint dla klientów
- ✅ System konfiguracji przez zmienne środowiskowe
- ✅ Endpoint do pobierania konfiguracji IRC
- ✅ Obsługa wielu jednoczesnych połączeń
- ✅ Real-time przekazywanie wiadomości

### Planowane Funkcjonalności

- [ ] Autentykacja użytkowników
- [ ] Persystencja wiadomości
- [ ] Historia czatu
- [ ] Multi-channel support per user
- [ ] File upload/download
- [ ] SSL/TLS dla WebSocket

## Licencja

MIT
