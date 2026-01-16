/// Translations for IRC service system messages
class IrcTranslations {
  static const Map<String, Map<String, String>> _translations = {
    'connecting': {'en': 'Connecting to backend', 'pl': 'Łączenie z backendem'},
    'connected': {'en': 'Connected to server!', 'pl': 'Połączono z serwerem!'},
    'using_nickname': {'en': 'Using nickname:', 'pl': 'Używany nick:'},
    'sent_auth': {
      'en': 'Connecting to IRC server...',
      'pl': 'Łączenie z serwerem IRC...',
    },
    'joining_channel': {'en': 'Joining channel', 'pl': 'Dołączanie do kanału'},
    'joined_channel': {
      'en': 'Successfully joined channel!',
      'pl': 'Pomyślnie dołączono do kanału!',
    },
    'active_users': {'en': 'Active users:', 'pl': 'Aktywni użytkownicy:'},
    'joined': {'en': 'joined the channel', 'pl': 'dołączył do kanału'},
    'left': {'en': 'left the channel', 'pl': 'opuścił kanał'},
    'quit': {'en': 'quit', 'pl': 'rozłączył się'},
    'disconnected': {
      'en': 'Disconnected from server',
      'pl': 'Rozłączono z serwerem',
    },
    'connection_error': {
      'en': 'Connection error occurred',
      'pl': 'Wystąpił błąd połączenia',
    },
    'connection_refused': {
      'en': 'Connection refused - Backend is not running or unreachable',
      'pl': 'Połączenie odrzucone - Backend nie działa lub jest niedostępny',
    },
    'connection_timeout': {
      'en': 'Connection timeout - Backend is taking too long to respond',
      'pl': 'Timeout połączenia - Backend zbyt długo nie odpowiada',
    },
    'invalid_backend_url': {
      'en': 'Invalid backend URL: ',
      'pl': 'Błędny adres backendu: ',
    },
    'network_error': {
      'en': 'Network error - Check your internet connection',
      'pl': 'Błąd sieciowy - Sprawdź swoje połączenie internetowe',
    },
  };

  /// Get translated message for a key
  /// [key] - Translation key
  /// [isPolish] - Whether to use Polish translation
  /// [suffix] - Optional suffix to append
  static String get(String key, {required bool isPolish, String? suffix}) {
    final lang = isPolish ? 'pl' : 'en';
    final translation =
        _translations[key]?[lang] ?? _translations[key]?['en'] ?? key;
    return suffix != null ? '$translation $suffix' : translation;
  }
}
