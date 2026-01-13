# GehChat - Testing Guide

## Running Tests

### Backend Tests (Python/pytest)

#### Using VS Code Tasks
1. Press `Ctrl+Shift+P` and type "Run Task"
2. Select one of:
   - **Test Backend (pytest)** - Run all backend tests
   - **Test Backend with Coverage** - Run tests with coverage report
   - **Test Backend (single file)** - Run tests in current file

#### Using Terminal
```powershell
# Navigate to Backend directory
cd Backend

# Run all tests
python -m pytest tests/ -v

# Run with coverage
python -m pytest tests/ -v --cov=. --cov-report=term-missing --cov-report=html

# Run specific test file
python -m pytest tests/test_config.py -v

# Run specific test
python -m pytest tests/test_main.py::TestHealthEndpoints::test_root_endpoint -v
```

#### Using VS Code Testing Sidebar
1. Click on the Testing icon in the Activity Bar (flask icon)
2. Tests will be automatically discovered
3. Click the play button next to any test to run it
4. Click the bug icon to debug a test

### Frontend Tests (Flutter/Dart)

#### Using VS Code Tasks
1. Press `Ctrl+Shift+P` and type "Run Task"
2. Select one of:
   - **Test Frontend (Flutter)** - Run all frontend tests
   - **Test Frontend with Coverage** - Run tests with coverage report
   - **Test Frontend (single file)** - Run tests in current file

#### Using Terminal
```powershell
# Navigate to Frontend directory
cd Frontend/geh_chat_frontend

# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/irc_service_test.dart

# Run tests with verbose output
flutter test --reporter expanded
```

#### Using VS Code Flutter Extension
1. Open any test file (e.g., `irc_service_test.dart`)
2. Click the "Run" button that appears above each test
3. Or use the Testing sidebar

### Run All Tests

#### Using VS Code Task
1. Press `Ctrl+Shift+B` (default test task)
2. Or select **Test All** from task list

#### Using Terminal
```powershell
# Backend tests
cd Backend
python -m pytest tests/ -v

# Frontend tests
cd Frontend/geh_chat_frontend
flutter test
```

## Test Structure

### Backend Tests
```
Backend/
├── tests/
│   ├── __init__.py
│   ├── test_config.py      # Configuration tests
│   └── test_main.py        # IRC Bridge and API tests
└── pytest.ini              # Pytest configuration
```

### Frontend Tests
```
Frontend/geh_chat_frontend/
└── test/
    ├── config/
    │   └── backend_config_test.dart
    ├── models/
    │   └── chat_state_test.dart
    ├── services/
    │   └── irc_service_test.dart
    └── widget_test.dart
```

## Coverage Reports

### Backend Coverage
After running tests with coverage, open:
- Terminal output for summary
- `Backend/htmlcov/index.html` for detailed HTML report

### Frontend Coverage
After running `flutter test --coverage`:
```powershell
# Install lcov tools (if not installed)
choco install lcov

# Generate HTML report
cd Frontend/geh_chat_frontend
genhtml coverage/lcov.info -o coverage/html

# Open coverage/html/index.html in browser
```

## Keyboard Shortcuts

- `Ctrl+Shift+B` - Run default test task (Test All)
- `Ctrl+Shift+P` → "Run Task" - Open task selector
- `F5` - Start debugging with current configuration
- `Ctrl+F5` - Run without debugging

## Test Categories

### Backend
- **Unit Tests** - Test individual functions and classes
- **Integration Tests** - Test WebSocket and IRC bridge functionality
- **API Tests** - Test REST endpoints

### Frontend
- **Unit Tests** - Test services, models, and configurations
- **Widget Tests** - Test UI components
- **Integration Tests** - Test app flows (future)

## Tips

1. **Watch Mode**: Tests don't have built-in watch mode, but you can use tasks to re-run easily
2. **Debug Tests**: Use the debug configurations in launch.json to debug tests
3. **Coverage**: Regular runs with coverage help maintain code quality
4. **CI/CD Ready**: All test commands work in CI/CD pipelines

## Installing Test Dependencies

### Backend
```powershell
cd Backend
pip install -r requirements.txt
```

### Frontend
```powershell
cd Frontend/geh_chat_frontend
flutter pub get
```

## Next Steps

- Add more integration tests
- Set up continuous integration
- Add E2E tests for complete workflows
- Configure code coverage thresholds
