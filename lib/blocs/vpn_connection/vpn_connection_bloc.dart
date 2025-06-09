import 'dart:async';

import 'package_exporter.dart'; // Assuming you have a package exporter for flutter_bloc, equatable
import 'package:flutter/services.dart'; // For PlatformException and channel definitions
import 'package:meta/meta.dart';

part 'vpn_connection_event.dart';
part 'vpn_connection_state.dart';

class VpnConnectionBloc extends Bloc<VpnConnectionEvent, VpnConnectionState> {
  final MethodChannel _vpnControlChannel = const MethodChannel('com.example.your_app_name/vpn_control');
  final EventChannel _vpnStatusChannel = const EventChannel('com.example.your_app_name/vpn_status');
  StreamSubscription? _vpnStatusSubscription;

  // To keep track of the config being processed during permission request
  ConnectVpnRequested? _pendingConnectionRequest;

  VpnConnectionBloc() : super(const VpnConnectionState()) {
    on<RequestVpnPermissionRequested>(_onRequestVpnPermissionRequested);
    on<_VpnPermissionResultReceived>(_onVpnPermissionResultReceived);
    on<ConnectVpnRequested>(_onConnectVpnRequested);
    on<DisconnectVpnRequested>(_onDisconnectVpnRequested);
    on<_NativeVpnStatusChanged>(_onNativeVpnStatusChanged);

    _listenToNativeVpnStatus();
    // Optionally, check initial VPN status from native side if possible/needed
    // _checkInitialVpnStatus();
  }

  void _listenToNativeVpnStatus() {
    _vpnStatusSubscription = _vpnStatusChannel.receiveBroadcastStream().listen(
      (nativeStatus) {
        if (nativeStatus is String) {
          add(_NativeVpnStatusChanged(nativeStatus));
        } else {
          // Handle unexpected status type
           add(const _NativeVpnStatusChanged("ERROR:Unexpected native status type"));
        }
      },
      onError: (error) {
        add(_NativeVpnStatusChanged("ERROR: ${error.message ?? 'Native listener error'}"));
      },
    );
  }

  // void _checkInitialVpnStatus() async {
  //   try {
  //     final String? initialStatus = await _vpnControlChannel.invokeMethod('getVpnStatus');
  //     if (initialStatus != null) {
  //       add(_NativeVpnStatusChanged(initialStatus));
  //     }
  //   } on PlatformException catch (e) {
  //     add(_NativeVpnStatusChanged("ERROR: Failed to get initial status: ${e.message}"));
  //   }
  // }

  Future<void> _onRequestVpnPermissionRequested(
    RequestVpnPermissionRequested event,
    Emitter<VpnConnectionState> emit,
  ) async {
    try {
      final bool? granted = await _vpnControlChannel.invokeMethod('requestVpnPermission');
      add(_VpnPermissionResultReceived(granted ?? false));
    } on PlatformException catch (e) {
      emit(state.copyWith(status: VpnStatus.error, errorMessage: "Permission request failed: ${e.message}"));
    }
  }

  Future<void> _onVpnPermissionResultReceived(
    _VpnPermissionResultReceived event,
    Emitter<VpnConnectionState> emit,
  ) async {
    if (event.isGranted) {
      if (_pendingConnectionRequest != null) {
        // If a connection was pending permission, proceed with it
        add(ConnectVpnRequested(
            configJson: _pendingConnectionRequest!.configJson,
            serverAlias: _pendingConnectionRequest!.serverAlias
        ));
        _pendingConnectionRequest = null; // Clear pending request
      } else {
        // Permission granted, but no specific connection was pending.
        // UI might want to reflect this, or it's just an idle grant.
        emit(state.copyWith(status: VpnStatus.disconnected, errorMessage: "VPN Permission Granted. Ready to connect."));
      }
    } else {
      _pendingConnectionRequest = null; // Clear if permission denied
      emit(state.copyWith(status: VpnStatus.disconnected, errorMessage: "VPN Permission Denied. Cannot connect."));
    }
  }


  Future<void> _onConnectVpnRequested(
    ConnectVpnRequested event,
    Emitter<VpnConnectionState> emit,
  ) async {
    emit(state.copyWith(status: VpnStatus.connecting, connectedServerAlias: event.serverAlias, clearErrorMessage: true));
    try {
      // First, check if permission is needed by trying to prepare.
      // The native side of 'requestVpnPermission' should handle VpnService.prepare()
      // and return true if already granted or successfully granted, false otherwise.
      final bool? permissionGranted = await _vpnControlChannel.invokeMethod('requestVpnPermission');

      if (permissionGranted == true) {
        await _vpnControlChannel.invokeMethod('startVpn', {'configJson': event.configJson});
        // Native side will send "CONNECTING", then "CONNECTED" or "ERROR" via EventChannel
      } else {
         // Store the request and wait for permission result via _VpnPermissionResultReceived
        _pendingConnectionRequest = event;
        // The requestVpnPermission method should have already triggered the OS dialog.
        // The state will be updated once _VpnPermissionResultReceived is processed.
        // UI should ideally show a message "Waiting for VPN permission..."
        emit(state.copyWith(status: VpnStatus.permissionNeeded, connectedServerAlias: event.serverAlias));
      }
    } on PlatformException catch (e) {
      emit(state.copyWith(status: VpnStatus.error, errorMessage: "Failed to start VPN: ${e.message}", clearConnectedServer: true));
    }
  }

  Future<void> _onDisconnectVpnRequested(
    DisconnectVpnRequested event,
    Emitter<VpnConnectionState> emit,
  ) async {
    emit(state.copyWith(status: VpnStatus.disconnecting, clearErrorMessage: true));
    try {
      await _vpnControlChannel.invokeMethod('stopVpn');
      // Native side will send "DISCONNECTING", then "DISCONNECTED" or "ERROR" via EventChannel
      // If native side doesn't explicitly send "DISCONNECTING", Flutter can assume it.
    } on PlatformException catch (e) {
      emit(state.copyWith(status: VpnStatus.error, errorMessage: "Failed to stop VPN: ${e.message}"));
      // Even on error, attempt to reflect a disconnected-like state if appropriate,
      // or rely on native status push to eventually correct it.
    }
  }

  void _onNativeVpnStatusChanged(
    _NativeVpnStatusChanged event,
    Emitter<VpnConnectionState> emit,
  ) {
    // Normalize native status strings to BLoC states
    // These strings MUST match what the native Android code sends.
    final String nativeStatus = event.nativeStatus.toUpperCase();
    print("Native VPN Status Changed: $nativeStatus"); // For debugging

    if (nativeStatus.startsWith("ERROR:")) {
      emit(state.copyWith(status: VpnStatus.error, errorMessage: nativeStatus, clearConnectedServer: true));
    } else {
      switch (nativeStatus) {
        case "CONNECTED":
          // connectedServerAlias should have been set when ConnectVpnRequested was processed
          emit(state.copyWith(status: VpnStatus.connected, clearErrorMessage: true));
          break;
        case "CONNECTING":
          // connectedServerAlias should have been set
          emit(state.copyWith(status: VpnStatus.connecting, clearErrorMessage: true));
          break;
        case "DISCONNECTED":
          emit(state.copyWith(status: VpnStatus.disconnected, clearErrorMessage: true, clearConnectedServer: true));
          _pendingConnectionRequest = null; // Clear any pending requests on disconnect
          break;
        case "DISCONNECTING":
           emit(state.copyWith(status: VpnStatus.disconnecting, clearErrorMessage: true));
          break;
        case "PERMISSION_NEEDED": // Example if native explicitly sends this
          emit(state.copyWith(status: VpnStatus.permissionNeeded, clearErrorMessage: true));
          break;
        default:
          // Handle unknown status, perhaps map to error or log
          emit(state.copyWith(status: VpnStatus.error, errorMessage: "Unknown native status: $nativeStatus"));
      }
    }
  }

  @override
  Future<void> close() {
    _vpnStatusSubscription?.cancel();
    return super.close();
  }
}
