# 🚀 How to Run Full Stack GehChat

## Method 1: Automatic Startup via VS Code (Recommended ⭐)

### Option A: Using Tasks
1. Press `Ctrl+Shift+P` (Command Palette)
2. Type: **Tasks: Run Task**
3. Select: **Start Backend & Frontend**

✅ This will start both servers simultaneously in separate terminals!

### Option B: Using Debugger
1. Press `Ctrl+Shift+D` or click the ▶️🐛 (Run and Debug) icon
2. From the dropdown menu select: **🚀 Full Stack: Backend + Frontend**
3. Press `F5` or click the green Play button

✅ Both projects will run in debug mode with breakpoint support!

---

## Method 2: Manual Startup

### Terminal 1: Backend (Python)
```powershell
cd Backend
.\venv\Scripts\Activate.ps1
python main.py
```
✅ Backend will be available at: **http://localhost:8000**
📚 API Documentation: **http://localhost:8000/docs**

### Terminal 2: Frontend (Flutter)
```powershell
cd Frontend\geh_chat_frontend
flutter run -d windows
```
✅ Flutter application will run on Windows

---

## 🔧 First Run - Installing Dependencies

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

**OR use Task in VS Code:**
- `Ctrl+Shift+P` → **Tasks: Run Task** → **Install All Dependencies**

---

## 📡 Backend Endpoints

After starting the backend, it provides:

| Endpoint | Type | Description |
|----------|------|-------------|
| `http://localhost:8000` | GET | Health check |
| `http://localhost:8000/api/health` | GET | Detailed health status |
| `http://localhost:8000/docs` | GET | Swagger UI (Interactive documentation) |
| `http://localhost:8000/redoc` | GET | ReDoc (Alternative documentation) |
| `ws://localhost:8000/ws` | WebSocket | Real-time communication |

---

## 🎯 Testing

### Test Backend with cURL
```powershell
# Health check
curl http://localhost:8000

# Detailed health
curl http://localhost:8000/api/health
```

### Test WebSocket via JavaScript Console
```javascript
const ws = new WebSocket('ws://localhost:8000/ws');
ws.onopen = () => ws.send('Hello from browser!');
ws.onmessage = (e) => console.log('Received:', e.data);
```

---

## 🛑 Stopping Servers

### Backend
- In the terminal where backend is running: `Ctrl+C`
- Or close the terminal

### Frontend
- In the terminal where Flutter is running: `q` (quit)
- Or close the application window

### In Debug Mode (F5)
- Press the red ⏹️ (Stop) button in the top bar
- Or press `Shift+F5`

---

## 🔍 Useful VS Code Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+P` | Command Palette (run tasks) |
| `Ctrl+Shift+D` | Open Debug panel |
| `F5` | Start Debugging |
| `Shift+F5` | Stop Debugging |
| `Ctrl+C` | Stop process in terminal |
| `` Ctrl+` `` | Open/close terminal |

---

## ⚠️ Troubleshooting

### Backend won't start
```powershell
# Make sure venv is activated
cd Backend
.\venv\Scripts\Activate.ps1

# Reinstall dependencies
pip install -r requirements.txt

# Check if port 8000 is free
netstat -ano | findstr :8000
```

### Frontend won't compile
```powershell
cd Frontend\geh_chat_frontend
flutter clean
flutter pub get
flutter run -d windows
```

### Port 8000 already in use
Change the port in `Backend/main.py`:
```python
uvicorn.run(
    "main:app",
    host="0.0.0.0",
    port=8001,  # Change to a different port
    reload=True
)
```

---

## 📚 Next Steps

1. **Browse API**: http://localhost:8000/docs
2. **Test WebSocket**: Use tools like Postman or websocat
3. **Modify code**: Both servers have hot-reload!
   - Backend: Uvicorn will automatically reload on .py changes
   - Frontend: Flutter hot-reload: press `r` in terminal

---

**Happy coding! 🎉**
