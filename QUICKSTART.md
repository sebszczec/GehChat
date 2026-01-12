# 🚀 Jak Uruchomić Full Stack GehChat

## Metoda 1: Automatyczne Uruchomienie przez VS Code (Zalecane ⭐)

### Opcja A: Używając Tasks
1. Naciśnij `Ctrl+Shift+P` (Command Palette)
2. Wpisz: **Tasks: Run Task**
3. Wybierz: **Start Backend & Frontend**

✅ To uruchomi oba serwery jednocześnie w osobnych terminalach!

### Opcja B: Używając Debuggera
1. Naciśnij `Ctrl+Shift+D` lub kliknij ikonę ▶️🐛 (Run and Debug)
2. Z dropdown menu wybierz: **🚀 Full Stack: Backend + Frontend**
3. Naciśnij `F5` lub kliknij zielony przycisk Play

✅ Oba projekty uruchomią się w trybie debug z możliwością breakpointów!

---

## Metoda 2: Ręczne Uruchomienie

### Terminal 1: Backend (Python)
```powershell
cd Backend
.\venv\Scripts\Activate.ps1
python main.py
```
✅ Backend będzie dostępny pod: **http://localhost:8000**
📚 Dokumentacja API: **http://localhost:8000/docs**

### Terminal 2: Frontend (Flutter)
```powershell
cd Frontend\geh_chat_frontend
flutter run -d windows
```
✅ Aplikacja Flutter uruchomi się na Windows

---

## 🔧 Pierwsze Uruchomienie - Instalacja Zależności

### Backend
```powershell
cd Backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Frontend
```powershell
cd Frontend\geh_chat_frontend
flutter pub get
```

**LUB użyj Task w VS Code:**
- `Ctrl+Shift+P` → **Tasks: Run Task** → **Install All Dependencies**

---

## 📡 Endpointy Backendu

Po uruchomieniu backend udostępnia:

| Endpoint | Typ | Opis |
|----------|-----|------|
| `http://localhost:8000` | GET | Health check |
| `http://localhost:8000/api/health` | GET | Detailed health status |
| `http://localhost:8000/docs` | GET | Swagger UI (Interaktywna dokumentacja) |
| `http://localhost:8000/redoc` | GET | ReDoc (Alternatywna dokumentacja) |
| `ws://localhost:8000/ws` | WebSocket | Real-time komunikacja |

---

## 🎯 Testowanie

### Test Backend przez cURL
```powershell
# Health check
curl http://localhost:8000

# Detailed health
curl http://localhost:8000/api/health
```

### Test WebSocket przez JavaScript Console
```javascript
const ws = new WebSocket('ws://localhost:8000/ws');
ws.onopen = () => ws.send('Hello from browser!');
ws.onmessage = (e) => console.log('Received:', e.data);
```

---

## 🛑 Zatrzymywanie Serwerów

### Backend
- W terminalu gdzie działa backend: `Ctrl+C`
- Lub zamknij terminal

### Frontend
- W terminalu gdzie działa Flutter: `q` (quit)
- Lub zamknij okno aplikacji

### W trybie Debug (F5)
- Naciśnij czerwony przycisk ⏹️ (Stop) w górnym pasku
- Lub `Shift+F5`

---

## 🔍 Przydatne Skróty VS Code

| Skrót | Akcja |
|-------|-------|
| `Ctrl+Shift+P` | Command Palette (uruchamianie tasków) |
| `Ctrl+Shift+D` | Otwórz panel Debug |
| `F5` | Start Debugging |
| `Shift+F5` | Stop Debugging |
| `Ctrl+C` | Stop procesu w terminalu |
| `` Ctrl+` `` | Otwórz/zamknij terminal |

---

## ⚠️ Troubleshooting

### Backend nie startuje
```powershell
# Upewnij się że venv jest aktywne
cd Backend
.\venv\Scripts\Activate.ps1

# Reinstaluj zależności
pip install -r requirements.txt

# Sprawdź czy port 8000 jest wolny
netstat -ano | findstr :8000
```

### Frontend nie kompiluje się
```powershell
cd Frontend\geh_chat_frontend
flutter clean
flutter pub get
flutter run -d windows
```

### Port 8000 już zajęty
Zmień port w `Backend/main.py`:
```python
uvicorn.run(
    "main:app",
    host="0.0.0.0",
    port=8001,  # Zmień na inny port
    reload=True
)
```

---

## 📚 Dalsze Kroki

1. **Przeglądaj API**: http://localhost:8000/docs
2. **Testuj WebSocket**: Użyj narzędzia jak Postman lub websocat
3. **Modyfikuj kod**: Oba serwery mają hot-reload!
   - Backend: Uvicorn automatycznie przeładuje przy zmianie .py
   - Frontend: Flutter hot-reload: `r` w terminalu

---

**Miłego kodowania! 🎉**
