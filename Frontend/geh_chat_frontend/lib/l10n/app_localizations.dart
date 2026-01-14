import 'package:flutter/material.dart';

abstract class AppLocalizations {
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
  }

  String get appTitle;
  String get connecting;
  String get connected;
  String get disconnected;
  String get connectionError;
  String get mainChannel;
  String get privateChats;
  String get users;
  String get typeMessage;
  String get send;
  String get startPrivateChat;
  String get close;
  String get reconnect;
  String get disconnect;
  String get confirmDisconnect;
  String get yes;
  String get no;
  String get hideUsers;
  String get hidePrivateChats;
  String get noMessagesYet;
  String get welcomeToGehChat;
  String get configureConnectionSettings;
  String get pleaseFillAllFields;
  String get invalidPortNumber;
  String get invalidIpAddress;
  String get connectionFailed;
  String get ircNotSupportedInBrowser;
  String get useDesktopOrMobile;
  String get noPrivateChats;
  String get server;
  String get port;
  String get channel;
  String get nickname;
  String get generateNewNickname;
  String get debugLogLevel;
  String get showAllIrcMessages;
  String get connect;
  String get abort;
  String get connectionAborted;
  String get channelHint;
  String get systemMessages;
  String get noSystemMessages;
  String get backendServer;
  String get backendPort;
  String get hostUnreachable;
  String get connectionRefused;
  String get hostNotFound;
  String get cannotConnectToBackend;
  String get connectionTimeout;
}

class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn();

  @override
  String get appTitle => 'GehChat';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connectionError => 'Connection Error';

  @override
  String get mainChannel => 'Main Channel';

  @override
  String get privateChats => 'Private Chats';

  @override
  String get users => 'Users';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get send => 'Send';

  @override
  String get startPrivateChat => 'Start Private Chat';

  @override
  String get close => 'Close';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get confirmDisconnect => 'Are you sure you want to disconnect?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get hideUsers => 'Hide users';

  @override
  String get hidePrivateChats => 'Hide private chats';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get welcomeToGehChat => 'Welcome to GehChat';

  @override
  String get configureConnectionSettings =>
      'Configure your connection settings';

  @override
  String get pleaseFillAllFields => 'Please fill in all fields';

  @override
  String get invalidPortNumber => 'Invalid port number';

  @override
  String get invalidIpAddress => 'Invalid IP address or hostname';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get ircNotSupportedInBrowser =>
      'IRC connections are not supported in web browsers.';

  @override
  String get useDesktopOrMobile =>
      'Please use the desktop or mobile version of this app.';

  @override
  String get noPrivateChats => 'No private chats';

  @override
  String get server => 'Server';

  @override
  String get port => 'Port';

  @override
  String get channel => 'Channel';

  @override
  String get nickname => 'Nickname';

  @override
  String get generateNewNickname => 'Generate new nickname';

  @override
  String get debugLogLevel => 'Debug Log Level';

  @override
  String get showAllIrcMessages => 'Show all IRC protocol messages in chat';

  @override
  String get connect => 'Connect';

  @override
  String get abort => 'Abort';

  @override
  String get connectionAborted => 'Connection aborted';

  @override
  String get channelHint => '#channel';

  @override
  String get systemMessages => 'System Messages';

  @override
  String get noSystemMessages => 'No system messages';

  @override
  String get backendServer => 'Backend Server';

  @override
  String get backendPort => 'Backend Port';

  @override
  String get hostUnreachable => 'Host is unreachable';

  @override
  String get connectionRefused => 'Connection refused';

  @override
  String get hostNotFound => 'Host not found';

  @override
  String get cannotConnectToBackend => 'Cannot connect to backend';

  @override
  String get connectionTimeout => 'Connection timeout - server not responding';
}

// Polish localization ready to be implemented
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl();

  @override
  String get appTitle => 'GehChat';

  @override
  String get connecting => 'Łączenie...';

  @override
  String get connected => 'Połączono';

  @override
  String get disconnected => 'Rozłączono';

  @override
  String get connectionError => 'Błąd połączenia';

  @override
  String get mainChannel => 'Kanał główny';

  @override
  String get privateChats => 'Prywatne czaty';

  @override
  String get users => 'Użytkownicy';

  @override
  String get typeMessage => 'Wpisz wiadomość...';

  @override
  String get send => 'Wyślij';

  @override
  String get startPrivateChat => 'Rozpocznij prywatny czat';

  @override
  String get close => 'Zamknij';

  @override
  String get reconnect => 'Połącz ponownie';

  @override
  String get disconnect => 'Rozłącz';

  @override
  String get confirmDisconnect => 'Czy na pewno chcesz się rozłączyć?';

  @override
  String get yes => 'Tak';

  @override
  String get no => 'Nie';

  @override
  String get hideUsers => 'Ukryj użytkowników';

  @override
  String get hidePrivateChats => 'Ukryj prywatne czaty';

  @override
  String get noMessagesYet => 'Brak wiadomości';

  @override
  String get welcomeToGehChat => 'Witaj w GehChat';

  @override
  String get configureConnectionSettings => 'Skonfiguruj ustawienia połączenia';

  @override
  String get pleaseFillAllFields => 'Wypełnij wszystkie pola';

  @override
  String get invalidPortNumber => 'Nieprawidłowy numer portu';

  @override
  String get invalidIpAddress => 'Nieprawidłowy adres IP lub nazwa hosta';

  @override
  String get connectionFailed => 'Połączenie nieudane';

  @override
  String get ircNotSupportedInBrowser =>
      'Połączenia IRC nie są wspierane w przeglądarkach.';

  @override
  String get useDesktopOrMobile =>
      'Użyj wersji desktopowej lub mobilnej aplikacji.';

  @override
  String get noPrivateChats => 'Brak prywatnych czatów';

  @override
  String get server => 'Serwer';

  @override
  String get port => 'Port';

  @override
  String get channel => 'Kanał';

  @override
  String get nickname => 'Pseudonim';

  @override
  String get generateNewNickname => 'Wygeneruj nowy pseudonim';

  @override
  String get debugLogLevel => 'Tryb debugowania';

  @override
  String get showAllIrcMessages =>
      'Pokaż wszystkie komunikaty protokołu IRC na czacie';

  @override
  String get connect => 'Połącz';

  @override
  String get abort => 'Anuluj';

  @override
  String get connectionAborted => 'Połączenie anulowane';

  @override
  String get channelHint => '#kanał';

  @override
  String get systemMessages => 'Wiadomości systemowe';

  @override
  String get noSystemMessages => 'Brak wiadomości systemowych';

  @override
  String get backendServer => 'Serwer backend';

  @override
  String get backendPort => 'Port backend';

  @override
  String get hostUnreachable => 'Host jest nieosiągalny';

  @override
  String get connectionRefused => 'Połączenie odrzucone';

  @override
  String get hostNotFound => 'Host nie znaleziony';

  @override
  String get cannotConnectToBackend => 'Nie można połączyć się z backendem';

  @override
  String get connectionTimeout => 'Timeout połączenia - serwer nie odpowiada';
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'pl'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'pl':
        return AppLocalizationsPl();
      case 'en':
      default:
        return AppLocalizationsEn();
    }
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
