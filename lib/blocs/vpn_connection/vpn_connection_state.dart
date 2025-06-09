part of 'vpn_connection_bloc.dart';

enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  permissionNeeded, // Waiting for user to grant VPN permission
  error,
}

class VpnConnectionState extends Equatable {
  final VpnStatus status;
  final String? errorMessage;
  final String? connectedServerAlias; // Alias of the currently connected server

  const VpnConnectionState({
    this.status = VpnStatus.disconnected,
    this.errorMessage,
    this.connectedServerAlias,
  });

  // Helper for creating new states based on the current one
  VpnConnectionState copyWith({
    VpnStatus? status,
    String? errorMessage,
    String? connectedServerAlias,
    bool clearErrorMessage = false, // Utility to explicitly clear error message
    bool clearConnectedServer = false, // Utility to explicitly clear server alias
  }) {
    return VpnConnectionState(
      status: status ?? this.status,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      connectedServerAlias: clearConnectedServer ? null : connectedServerAlias ?? this.connectedServerAlias,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, connectedServerAlias];
}
