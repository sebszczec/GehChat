# Łączenie Aplikacji Android z Backendem w Sieci Lokalnej

## Problem
Aplikacja Flutter na Android nie może się połączyć z Backendem uruchomionym na komputerze lokalnym (localhost:8000).

## Rozwiązanie: Dwa Kroki

### 1. **Zmień adres Backend URL w aplikacji**

Zmień `localhost` na IP komputera w sieci lokalnej: `192.168.68.77`

#### W pliku `Frontend/geh_chat_frontend/lib/services/irc_service.dart`:

```dart
IrcService({String? server, int? port, String? channel, String? backendUrl})
  : server = server ?? 'slaugh.pl',
    port = port ?? 6667,
    channel = channel ?? '#vorest',
    backendUrl = backendUrl ?? 'ws://192.168.68.77:8000/ws',  // ← Zmień tutaj
```

**LUB** przekaż adres IP dynamicznie podczas inicjalizacji (lepszą praktyka):

```dart
// W main.dart lub config
final irc = IrcService(
  backendUrl: 'ws://192.168.68.77:8000/ws'
);
```

### 2. **Otwórz Port 8000 w Windows Firewall**

#### Metoda A: Automatycznie (PowerShell jako Administrator)
```powershell
# Otwórz PowerShell jako Administrator i uruchom:
New-NetFirewallRule -DisplayName "GehChat Backend (Port 8000)" `
  -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8000
```

#### Metoda B: Ręcznie przez GUI Windows Defender

1. Otwórz **Windows Defender Firewall** (Windows Firewall)
   - Wciśnij `Win+S`, wpisz "Firewall" i otwórz

2. Kliknij **Allow an app through firewall**

3. Kliknij **Change settings** (jeśli trzeba)

4. Kliknij **Allow another app...**

5. Kliknij **Browse**, znajdź `Backend/venv/Scripts/python.exe`

6. Kliknij **Add**

7. Upewnij się że `python.exe` ma zaznaczony **Private** i **Public**

#### Metoda C: Ręcznie przez Advanced Settings

1. Otwórz **Windows Defender Firewall with Advanced Security**
   - Wciśnij `Win+S`, wpisz "Windows Defender Firewall with Advanced Security"

2. W lewym panelu kliknij **Inbound Rules**

3. W prawym panelu kliknij **New Rule...**

4. Wybierz **Port** → **Next**

5. Wybierz **TCP** i wpisz port `8000` → **Next**

6. Wybierz **Allow the connection** → **Next**

7. Zaznacz wszystkie profile (Domain, Private, Public) → **Next**

8. Wpisz nazwę: "GehChat Backend Port 8000" → **Finish**

### 3. **Sprawdź Łączność**

Na urządzeniu Android w terminalu (jeśli jest dostęp do powłoki):
```bash
# Sprawdź czy port jest dostępny
nc -zv 192.168.68.77 8000
```

Lub otwórz przeglądarkę na Android i przejdź do:
```
http://192.168.68.77:8000/
```

Powinna zostać wyświetlona wiadomość JSON o statusie serwera.

## Troubleshooting

### ❌ Backend nie uruchomiony
```bash
# W terminalu na komputerze:
cd Backend
python main.py
# Powinien pokazać:
# INFO:     Application startup complete [uvicorn]
```

### ❌ Port 8000 jest już w użyciu
```bash
# Sprawdź co zajmuje port:
netstat -ano | findstr :8000

# Zmień port w Backend/main.py:
# zmień BACKEND_PORT = 8000 na BACKEND_PORT = 8001
# i zaktualizuj URL w aplikacji
```

### ❌ Firewall blokuje połączenie
- Sprawdź czy reguła firewall'a jest dodana prawidłowo
- Spróbuj czasowo wyłączyć Windows Defender (tylko do testów!)
- Spróbuj się połączyć z innego urządzenia w sieci

### ❌ Android mówi "Connection refused"
- Upewnij się że IP `192.168.68.77` jest prawidłowe (sprawdź `ipconfig`)
- Sprawdź że Android i komputer są w tej samej sieci WiFi/Ethernet
- Upewnij się że Backend jest uruchomiony i słucha na `0.0.0.0:8000`

### ❌ Timeout/brak odpowiedzi
- Sprawdź czy firewall nie blokuje (dodaj regułę)
- Sprawdź czy backend jest na porcie 8000
- Sprawdź dzienniki aplikacji na urządzeniu Android

## Ustalenia

- **Komputer (Backend)**: `192.168.68.77:8000`
- **Android (Frontend)**: Łączy się do IP komputera
- **Port**: `8000` (zmień w kodzie jeśli zmienisz port)
- **Protokół**: WebSocket (`ws://`)

## Notatki

- Te zmiany są dla sieci **lokalnej** (LAN)
- W produkcji użyj właściwej domeny i SSL (wss://)
- Jeśli zmienisz IP komputera, zaktualizuj config w aplikacji
