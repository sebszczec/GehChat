# GehChat Development Agent

## Purpose
This agent is configured to assist with development work on the GehChat application, a chat platform with Flutter frontend and Python backend components.

## Critical Rules
1. **Do NOT commit changes to the repository** without explicit user permission
2. **Code Analysis Required**: Always analyze both Frontend (Flutter/Dart) and Backend (Python) code to understand:
   - Dependencies between components
   - Communication patterns and WebSocket integration
   - API endpoints and data models
3. **Testing is Mandatory**: After any code modification:
   - Run appropriate unit tests (pytest for Backend, Flutter tests for Frontend)
   - Write new tests if functionality changes
   - Check test coverage reports

## Project Context
- **Frontend**: Flutter application (Dart) located in `/Frontend/geh_chat_frontend/`
- **Backend**: Python application using Flask/FastAPI located in `/Backend/`
- **Communication**: WebSocket-based real-time messaging
- **Testing Framework**: pytest (Backend), Flutter test (Frontend)

## Available Tasks
- `Start Backend (Python)`: Run backend server
- `Start Frontend (Flutter)`: Run Flutter app on Windows
- `Test Backend (pytest)`: Execute all backend tests
- `Test Frontend (Flutter)`: Execute all frontend tests
- `Test All`: Run both backend and frontend tests in parallel
- `Test All with Coverage`: Generate coverage reports for both

## Development Workflow
1. Analyze requirements and existing code
2. Implement changes following project architecture
3. Run relevant tests before completion
4. Report test results and any issues
5. **Never push to repository** - wait for explicit permission

## Communication Protocol
- Understand WebSocket message formats used in GehChat
- Follow the established API contract between Frontend and Backend
- Maintain backward compatibility when modifying APIs

## Key Files to Understand
- Frontend: `lib/main.dart`, `lib/services/`, `lib/models/`
- Backend: `main.py`, `config.py`, test files
- Configuration: `pubspec.yaml` (Frontend), `requirements.txt` (Backend)

---

## 🔐 CRITICAL: Encryption Architecture (DO NOT BREAK)

### Encryption Overview
- **Type**: AES-256-CBC with per-session unique keys
- **Scope**: Frontend-to-Frontend private messages ONLY
- **Frontend-to-IRC**: Plain text (IRC doesn't support encryption)
- **Public Channel**: Plain text (all users see messages)

### Session Key Naming Convention ⚠️
**CRITICAL**: Both Backend and Frontend MUST use IDENTICAL sorting:

```
Session Key = sorted([user1, user2]) joined with underscore

Example:
  alice + bob    → sorted → ["alice", "bob"]   → "alice_bob"
  bob + alice    → sorted → ["alice", "bob"]   → "alice_bob" (SAME!)
  charlie + alice → sorted → ["alice", "charlie"] → "alice_charlie"
```

**WHY SORTING IS CRITICAL:**
- Ensures same session key for bidirectional communication
- `alice→bob` and `bob→alice` use identical encryption key
- Prevents "two different keys for same pair" problem
- If you change this, encryption BREAKS for bidirectional messages

### Server-Driven Encryption Setup (DO NOT CHANGE APPROACH)

The encryption setup is **Backend-controlled**, not client-initiated:

#### Backend Flow (Python - `main.py`)

1. **User Connects** - In `connect_to_irc()` handler:
   ```python
   # After user registers
   encryption_service.register_user(nickname)
   
   # Get list of other Frontend users needing encryption
   unencrypted_users = encryption_service.get_unencrypted_frontend_users(nickname)
   
   # Send setup instruction to Frontend
   send_to_client({
       "type": "setup_encryption",
       "users": unencrypted_users  # [other_user1, other_user2, ...]
   })
   
   # Mark sessions as pending
   for user in unencrypted_users:
       encryption_service.add_pending_session(nickname, user)
   ```

2. **Receive Confirmation** - In `encryption_session_ready` handler:
   ```python
   from_user = self.nickname
   to_user = message['with']
   
   # Backend creates session with sorted names
   users = sorted([from_user, to_user])
   session_key_name = f"{users[0]}_{users[1]}"
   
   # Establish Backend-side session
   encryption_service.establish_session(from_user, to_user)
   
   # Retrieve and send key
   key = encryption_service.session_keys[session_key_name]
   send_to_client({
       "type": "session_key",
       "session": session_key_name,
       "key": base64.b64encode(key).decode()
   })
   ```

#### Frontend Flow (Dart - `irc_service.dart`)

1. **Receive Setup Instruction** - Handler for `setup_encryption`:
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

2. **Send Message** - In `sendMessage()` method:
   ```dart
   // FOR FRONTEND USERS: Check session exists BEFORE allowing message
   final sessionKey = _getSessionKeyName(_nickname!, target);
   if (!_encryptionService.sessionKeys.containsKey(sessionKey)) {
     // Block message - encryption session not ready
     debugPrint('Cannot send: session not ready for $target');
     return;  // Silent block
   }
   
   // Session exists - encrypt and send
   final encryptedMessage = _encryptionService.encryptMessage(
     _nickname!,
     target,
     message,
   );
   ```

### Critical Methods to NOT Break

#### Backend (Python)
- `EncryptionService.register_user(nickname)` - Registers Frontend user
- `EncryptionService.establish_session(user1, user2)` - Creates sorted session
- `EncryptionService.get_unencrypted_frontend_users(for_user)` - Lists users needing encryption
- `EncryptionService.encrypt_message(sender, recipient, content)` - Uses sorted key
- `EncryptionService.decrypt_message(sender, recipient, content)` - Uses sorted key
- `EncryptionService.session_keys` - Dict of all active session keys (sorted names)

#### Frontend (Dart)
- `EncryptionService.establishSession(user1, user2)` - Creates local session with sorted key
- `EncryptionService.encryptMessage(sender, recipient, content)` - Encrypts with sorted key
- `EncryptionService.decryptMessage(sender, recipient, content)` - Decrypts with sorted key
- `EncryptionService.sessionKeys` - Map of active session keys (sorted names)
- `IrcService._getSessionKeyName(user1, user2)` - Returns sorted session name

### Message Handlers to NOT BREAK

#### Backend Handlers
1. **`connect_to_irc`** - Must send `setup_encryption` IMMEDIATELY after user registers
2. **`encryption_session_ready`** - Must establish Backend session and send `session_key`
3. **`session_key`** (Frontend) - Receives key and injects into local EncryptionService
4. **`message`** - For encrypted messages: decrypt if session exists, relay to recipient

#### Frontend Handlers
1. **`setup_encryption`** - Must establish local sessions for all users in list
2. **`encryption_session_ready`** - Confirms to Backend (sent FROM Frontend)
3. **`session_key`** - Receives key from Backend, injects into EncryptionService

### Common Mistakes to AVOID

❌ **DO NOT**:
- Use unsorted session names like `alice_bob` when `bob + alice` should match
- Manually create sessions only on first message (causes "first message problem")
- Allow Frontend to skip encryption session setup before sending
- Have Backend send session keys BEFORE receiving confirmation
- Create different encryption keys for `alice→bob` vs `bob→alice`

✅ **DO**:
- Always sort user names: `sorted([user1, user2])`
- Establish encryption BEFORE allowing messages
- Verify session exists before allowing message send (block if not ready)
- Ensure Backend creates session AFTER receiving `encryption_session_ready`
- Test bidirectional encryption (both directions must work with same key)

### Testing Encryption

Before commit, verify:

1. **Backend Tests** (38 tests minimum):
   ```bash
   pytest tests/ -v
   # MUST PASS: test_encrypt_decrypt_roundtrip, test_bidirectional_encryption
   ```

2. **Frontend Tests** (47 tests minimum):
   ```bash
   flutter test
   # MUST PASS: encryption_service_test.dart, irc_service_test.dart
   ```

3. **Integration Test** (manual with 2 Frontend clients):
   - Connect Frontend A → Backend sends `setup_encryption`
   - Connect Frontend B → Backend sends `setup_encryption` to both
   - Verify both get `encryption_session_ready` confirmations
   - Verify both receive `session_key` messages
   - Send message A→B → should encrypt and B should decrypt
   - Send message B→A → should encrypt and A should decrypt
   - **CRITICAL**: First message must decrypt correctly (this was the original problem)

### Recent Changes Made

**January 15, 2026 - Encryption Architecture Overhaul:**
- Implemented server-driven encryption setup (Backend controls all initiation)
- Fixed session key naming to use sorted format everywhere
- Added pre-message-send session verification (blocks unencrypted to Frontend users)
- Added `setup_encryption` handler for pro-active Backend setup
- Added `encryption_session_ready` handler for confirmation flow
- Resolved "first message decryption problem" by pre-establishing all sessions

---