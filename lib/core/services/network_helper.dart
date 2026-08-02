import 'dart:io';
import 'log_service.dart';

class NetworkHelper {
  static final NetworkHelper _instance = NetworkHelper._internal();
  factory NetworkHelper() => _instance;
  NetworkHelper._internal();

  Future<String> getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      String? fallback;
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              isLocalNetwork(addr.address)) {
            if (!_isVirtualNetwork(addr.address)) {
              return addr.address;
            }
            fallback ??= addr.address;
          }
        }
      }
      if (fallback != null) return fallback;
    } catch (e) {
      LogService.e('NetworkHelper.getLocalIP error: $e');
    }
    return '127.0.0.1';
  }

  bool _isVirtualNetwork(String ip) {
    if (ip.startsWith('192.168.56.')) return true;
    if (ip.startsWith('192.168.57.')) return true;
    if (ip.startsWith('192.168.99.')) return true;
    if (ip.startsWith('192.168.100.')) return true;
    if (ip.startsWith('10.0.2.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final secondOctet = int.tryParse(parts[1]) ?? 0;
        if (secondOctet >= 16 && secondOctet <= 31) return true;
      }
    }
    return false;
  }

  bool isLocalNetwork(String ip) {
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final secondOctet = int.tryParse(parts[1]) ?? 0;
        if (secondOctet >= 16 && secondOctet <= 31) return true;
      }
    }
    return false;
  }
}
