// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

// Placeholder for a more robust solution for unique IDs if needed,
// like an actual ID from the V2Ray config itself if consistently available,
// or a hash of the core config details. For now, using hashCode of original link.
int _generateIdFromLink(String link) {
  return link.hashCode;
}

class V2RayServerConfig {
  final int id; // Unique ID for database/list management
  final String originalLink; // The raw server link (e.g., vmess://...)
  final String alias; // User-friendly name, from 'ps' or 'remarks'
  final String address;
  final int port;
  final String userId; // UUID for VMess/VLESS, password for Shadowsocks/Trojan
  final String? network; // e.g., 'tcp', 'ws', 'h2'
  final String? headerType; // for tcp: 'none', 'http'
  final String? path; // for ws/h2
  final String? security; // 'tls', 'none', specific AEAD for SS
  final String? sni; // Server Name Indication for TLS
  final String? flow; // For VLESS flow control
  final String? host; // Host for ws headers

  // Stores the fully parsed V2Ray JSON configuration string,
  // ready to be passed to the V2Ray core.
  // For schemes like SS, this might be constructed.
  final String fullJsonConfig;

  V2RayServerConfig({
    required this.id,
    required this.originalLink,
    required this.alias,
    required this.address,
    required this.port,
    required this.userId,
    this.network,
    this.headerType,
    this.path,
    this.security,
    this.sni,
    this.flow,
    this.host,
    required this.fullJsonConfig,
  });

  @override
  String toString() {
    return 'V2RayServerConfig(id: $id, alias: $alias, address: $address, port: $port, userId: $userId, network: $network, security: $security, sni: $sni, fullJsonConfig: $fullJsonConfig)';
  }

  // Basic equality and hashCode
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is V2RayServerConfig &&
        other.id == id &&
        other.originalLink == originalLink;
  }

  @override
  int get hashCode => id.hashCode ^ originalLink.hashCode;

  // Example factory method to parse a VMess link
  // This is a simplified example and would need to be much more robust
  // and handle various edge cases and other schemes.
  static V2RayServerConfig? fromVmessLink(String vmessLink) {
    if (!vmessLink.startsWith('vmess://')) return null;

    try {
      final String encodedJson = vmessLink.substring('vmess://'.length);
      final String decodedJson = utf8.decode(base64.decode(encodedJson));
      final Map<String, dynamic> params = jsonDecode(decodedJson);

      // Extract common parameters
      final alias = params['ps']?.toString() ?? params['remarks']?.toString() ?? 'Unnamed VMess';
      final address = params['add']?.toString() ?? '';
      final port = params['port'] is String ? int.tryParse(params['port']) ?? 0 : params['port'] ?? 0;
      final userId = params['id']?.toString() ?? '';
      final network = params['net']?.toString(); // ws, tcp, etc.
      final headerType = params['type']?.toString(); // For tcp: none, http
      final path = params['path']?.toString(); // For ws
      final sni = params['sni']?.toString() ?? params['host']?.toString(); // SNI, sometimes 'host' is used
      final hostHeader = params['host']?.toString(); // Actual host for headers
      final security = params['tls']?.toString() ?? 'none'; // tls, none

      if (address.isEmpty || port == 0 || userId.isEmpty) {
        // Invalid essential data
        return null;
      }

      // Re-encode the JSON to ensure it's a valid JSON string for the core.
      // Or, ideally, construct the precise JSON the core expects if transformations are needed.
      final String coreJsonConfig = jsonEncode(params);

      return V2RayServerConfig(
        id: _generateIdFromLink(vmessLink),
        originalLink: vmessLink,
        alias: alias,
        address: address,
        port: port,
        userId: userId,
        network: network,
        headerType: headerType,
        path: path,
        security: security,
        sni: sni,
        host: hostHeader,
        fullJsonConfig: coreJsonConfig,
      );
    } catch (e) {
      print('Error parsing VMess link ($vmessLink): $e');
      return null;
    }
  }

  // Placeholder for other parsers like VLESS, SS, Trojan
  // static V2RayServerConfig? fromVlessLink(String vlessLink) { ... }
  // static V2RayServerConfig? fromSsLink(String ssLink) { ... }
}
