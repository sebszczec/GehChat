/// Utility class for validating network addresses
class NetworkValidator {
  /// Validates if a string is a valid IP address or domain name
  static bool isValidIpOrDomain(String server) {
    // IPv4 pattern - matches any IP address format with 4 octets
    final ipv4Pattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

    // Hostname/domain pattern (alphanumeric, dots, hyphens)
    final domainPattern = RegExp(
      r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$',
    );

    // localhost is always valid
    if (server.toLowerCase() == 'localhost' || server == '127.0.0.1') {
      return true;
    }

    // Check if it's a valid IPv4 (including special IPs like 10.0.2.2 for Android emulator)
    if (ipv4Pattern.hasMatch(server)) {
      final parts = server.split('.');
      // For IPv4, we accept any value 0-255 in each octet
      for (var part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) {
          return false;
        }
      }
      return true;
    }

    // Check if it's a valid domain/hostname
    if (domainPattern.hasMatch(server)) {
      return true;
    }

    return false;
  }

  /// Validates if a string is a valid port number (1-65535)
  static bool isValidPort(String portStr) {
    final port = int.tryParse(portStr);
    return port != null && port >= 1 && port <= 65535;
  }

  /// Parses a port string to int, returns null if invalid
  static int? parsePort(String portStr) {
    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      return null;
    }
    return port;
  }
}
