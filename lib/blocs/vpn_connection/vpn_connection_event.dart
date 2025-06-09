part of 'vpn_connection_bloc.dart';

abstract class VpnConnectionEvent extends Equatable {
  const VpnConnectionEvent();

  @override
  List<Object?> get props => [];
}

// User-initiated event to start the VPN connection
class ConnectVpnRequested extends VpnConnectionEvent {
  final String configJson; // The V2Ray JSON configuration string
  final String serverAlias; // Alias of the server being connected to

  const ConnectVpnRequested({required this.configJson, required this.serverAlias});

  @override
  List<Object?> get props => [configJson, serverAlias];
}

// User-initiated event to stop the VPN connection
class DisconnectVpnRequested extends VpnConnectionEvent {}

// Internal event triggered by native VPN status updates
class _NativeVpnStatusChanged extends VpnConnectionEvent {
  final String nativeStatus; // e.g., "CONNECTED", "DISCONNECTED", "CONNECTING", "ERROR:..."
  const _NativeVpnStatusChanged(this.nativeStatus);

  @override
  List<Object?> get props => [nativeStatus];
}

// Event to trigger VPN permission request
class RequestVpnPermissionRequested extends VpnConnectionEvent {}

// Internal event when VPN permission result is known
class _VpnPermissionResultReceived extends VpnConnectionEvent {
  final bool isGranted;
  const _VpnPermissionResultReceived(this.isGranted);

  @override
  List<Object?> get props => [isGranted];
}
