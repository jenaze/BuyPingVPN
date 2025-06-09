import 'dart:async';

import 'package:flutter/services.dart'; // For PlatformException
import 'package:your_app_name/models/app_info.dart';
import 'package:your_app_name/models/split_tunneling_settings.dart' hide SplitTunnelingMode; // Hide to use the BLoC's enum
import 'package:your_app_name/services/settings_service.dart'; // Flutter persistence
// Assuming a service to call the native platform channel for setting rules
// import 'package:your_app_name/services/vpn_rules_config_service.dart';
import 'package:package_exporter.dart'; // For bloc, equatable

part 'split_tunneling_event.dart';
part 'split_tunneling_state.dart';


// Mock AppService, replace with actual implementation
class AppService {
  static const MethodChannel _channel = MethodChannel('com.example.your_app_name/app_list');

  Future<List<AppInfo>> getInstalledApps({
    bool includeSystemApps = false,
    bool includeAppIcons = true,
  }) async {
    print('AppService: Fetching apps (includeSystem: $includeSystemApps, includeIcons: $includeAppIcons)');
    try {
      final List<dynamic>? appsData = await _channel.invokeMethod(
        'getInstalledApplications',
        {
          'includeSystemApps': includeSystemApps,
          'includeAppIcons': includeAppIcons,
        },
      );
      if (appsData == null) return [];
      return appsData
          .map((data) => AppInfo.fromMap(Map<String, dynamic>.from(data as Map)))
          .toList();
    } on PlatformException catch (e) {
      print("Failed to get installed apps: '${e.message}'.");
      throw Exception("Platform error fetching apps: ${e.message}");
    } catch (e) {
      print("Generic error fetching apps: $e");
      throw Exception("Error fetching apps: $e");
    }
  }
}

// Mock VpnRulesConfigService, replace with actual implementation
class VpnRulesConfigService {
  Future<bool> setNativeSplitTunnelingRules({
    required SplitTunnelingMode mode, // BLoC's enum
    required Set<String> packageNames,
  }) async {
    // Simulate platform channel call
    print('VpnRulesConfigService: Sending rules to native. Mode: $mode, Packages: ${packageNames.length}');
    // In real implementation, convert mode to string and call platform channel
    // For now, simulate success
    await Future.delayed(const Duration(milliseconds: 300));
    // if (Random().nextBool()) return true; // Simulate random success/failure
    // throw PlatformException(code: "NATIVE_ERROR_SIMULATED", message: "Simulated native error");
    return true;
  }
}


class SplitTunnelingBloc extends Bloc<SplitTunnelingEvent, SplitTunnelingState> {
  final AppService _appService;
  final SettingsService _settingsService; // Flutter persistence
  final VpnRulesConfigService _vpnRulesConfigService; // To send rules to native

  SplitTunnelingBloc({
    required AppService appService,
    required SettingsService settingsService,
    required VpnRulesConfigService vpnRulesConfigService,
  })  : _appService = appService,
        _settingsService = settingsService,
        _vpnRulesConfigService = vpnRulesConfigService,
        super(const SplitTunnelingState()) {
    on<InitializeSplitTunneling>(_onInitializeSplitTunneling);
    on<_SettingsLoaded>(_onSettingsLoaded);
    on<LoadInstalledApps>(_onLoadInstalledApps);
    on<ToggleAppSelection>(_onToggleAppSelection);
    on<ChangeSplitTunnelingMode>(_onChangeSplitTunnelingMode);
    on<SaveSplitTunnelingRules>(_onSaveSplitTunnelingRules);
    on<UpdateAppSearchQuery>(_onUpdateAppSearchQuery);
    on<ToggleSystemAppsVisibility>(_onToggleSystemAppsVisibility);
  }

  Future<void> _onInitializeSplitTunneling(
    InitializeSplitTunneling event,
    Emitter<SplitTunnelingState> emit,
  ) async {
    emit(state.copyWith(appListStatus: AppListStatus.loading, showSystemApps: event.initialShowSystemApps));
    try {
      final loadedSettings = await _settingsService.loadSplitTunnelingSettings();
      // Translate from persistence model to BLoC state enum if necessary
      final SplitTunnelingMode blocMode = SplitTunnelingMode.values.firstWhere(
            (e) => e.toString().split('.').last == loadedSettings.mode.toString().split('.').last,
            orElse: () => SplitTunnelingMode.allAppsUseVpn // Default if parsing fails
          );

      add(_SettingsLoaded(
          SplitTunnelingSettings( // Use the persistence model here for clarity
            mode: loadedSettings.mode, // from settings_service
            selectedPackageNames: loadedSettings.selectedPackageNames,
          )
      ));
      // Trigger app loading with potentially loaded 'showSystemApps' preference
      // For now, using event.initialShowSystemApps. A more robust way would be to load this preference too.
      add(LoadInstalledApps(includeSystemApps: state.showSystemApps, includeAppIcons: event.fetchAppIcons));

    } catch (e) {
      emit(state.copyWith(
          appListStatus: AppListStatus.error, errorMessage: "Failed to load saved settings: ${e.toString()}"));
      // Still try to load apps with default settings
      add(LoadInstalledApps(includeSystemApps: event.initialShowSystemApps, includeAppIcons: event.fetchAppIcons));
    }
  }

  void _onSettingsLoaded(
     _SettingsLoaded event,
     Emitter<SplitTunnelingState> emit,
  ) {
     // Translate from persistence model to BLoC state enum
      final SplitTunnelingMode blocMode = SplitTunnelingMode.values.firstWhere(
            (e) => e.toString().split('.').last == event.loadedSettings.mode.toString().split('.').last,
            orElse: () => SplitTunnelingMode.allAppsUseVpn // Default if parsing fails
          );
    emit(state.copyWith(
      currentMode: blocMode,
      selectedPackageNames: event.loadedSettings.selectedPackageNames,
      hasPendingChanges: false, // Settings just loaded, no pending changes yet
    ));
  }


  Future<void> _onLoadInstalledApps(
    LoadInstalledApps event,
    Emitter<SplitTunnelingState> emit,
  ) async {
    // Preserve current search query and other relevant state aspects if this is a reload
    emit(state.copyWith(appListStatus: AppListStatus.loading, showSystemApps: event.includeSystemApps, clearErrorMessage: true));
    try {
      final apps = await _appService.getInstalledApps(
        includeSystemApps: event.includeSystemApps,
        includeAppIcons: event.includeAppIcons,
      );
      apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
      emit(state.copyWith(
        appListStatus: AppListStatus.loaded,
        allApps: apps,
        filteredApps: _filterApps(apps, state.searchQuery),
      ));
    } catch (e) {
      emit(state.copyWith(
          appListStatus: AppListStatus.error, errorMessage: e.toString()));
    }
  }

  void _onToggleAppSelection(
    ToggleAppSelection event,
    Emitter<SplitTunnelingState> emit,
  ) {
    final newSelectedPackageNames = Set<String>.from(state.selectedPackageNames);
    if (newSelectedPackageNames.contains(event.packageName)) {
      newSelectedPackageNames.remove(event.packageName);
    } else {
      newSelectedPackageNames.add(event.packageName);
    }
    emit(state.copyWith(selectedPackageNames: newSelectedPackageNames, hasPendingChanges: true, saveStatus: SaveStatus.idle));
  }

  void _onChangeSplitTunnelingMode(
    ChangeSplitTunnelingMode event,
    Emitter<SplitTunnelingState> emit,
  ) {
    emit(state.copyWith(currentMode: event.mode, hasPendingChanges: true, saveStatus: SaveStatus.idle));
  }

  Future<void> _onSaveSplitTunnelingRules(
    SaveSplitTunnelingRules event,
    Emitter<SplitTunnelingState> emit,
  ) async {
    emit(state.copyWith(saveStatus: SaveStatus.saving, clearSaveErrorMessage: true));
    try {
      final settingsToSave = SplitTunnelingSettings( // Use persistence model
        mode: modeToPersistenceModel(state.currentMode), // Convert BLoC enum to persistence enum
        selectedPackageNames: state.selectedPackageNames,
      );

      // 1. Persist to Flutter's local storage
      await _settingsService.saveSplitTunnelingSettings(settingsToSave);

      // 2. Send rules to native Android side
      bool nativeSaveSuccess = await _vpnRulesConfigService.setNativeSplitTunnelingRules(
        mode: state.currentMode, // Pass BLoC enum directly
        packageNames: state.selectedPackageNames,
      );

      if (nativeSaveSuccess) {
        emit(state.copyWith(hasPendingChanges: false, saveStatus: SaveStatus.success));
      } else {
        // If native save failed, but Flutter save might have succeeded.
        // Consider how to handle this inconsistency. For now, mark as error.
        emit(state.copyWith(saveStatus: SaveStatus.error, saveErrorMessage: "Failed to apply rules to native system."));
      }
    } catch (e) {
      emit(state.copyWith(saveStatus: SaveStatus.error, saveErrorMessage: "Failed to save rules: ${e.toString()}"));
    }
  }

  void _onUpdateAppSearchQuery(
    UpdateAppSearchQuery event,
    Emitter<SplitTunnelingState> emit,
  ) {
    emit(state.copyWith(
      searchQuery: event.query,
      filteredApps: _filterApps(state.allApps, event.query),
    ));
  }

  Future<void> _onToggleSystemAppsVisibility(
     ToggleSystemAppsVisibility event,
     Emitter<SplitTunnelingState> emit,
  ) async {
    // Update the showSystemApps flag in the state first
    emit(state.copyWith(showSystemApps: event.showSystemApps));
    // Then reload apps with the new system apps visibility setting
    add(LoadInstalledApps(includeSystemApps: event.showSystemApps, includeAppIcons: true)); // Assuming icons are desired
  }

  List<AppInfo> _filterApps(List<AppInfo> apps, String query) {
    if (query.isEmpty) {
      return List.from(apps);
    }
    final lowerCaseQuery = query.toLowerCase();
    return apps
        .where((app) =>
            app.appName.toLowerCase().contains(lowerCaseQuery) ||
            app.packageName.toLowerCase().contains(lowerCaseQuery))
        .toList();
  }

  // Helper to convert BLoC enum to persistence enum if they are different
  // If they are the same, this is not strictly needed but good for separation
  your_app_name.models.split_tunneling_settings.SplitTunnelingMode modeToPersistenceModel(SplitTunnelingMode blocMode) {
    return your_app_name.models.split_tunneling_settings.SplitTunnelingMode.values.firstWhere(
      (e) => e.toString().split('.').last == blocMode.toString().split('.').last,
      // orElse: () => throw Exception("Mode conversion error") // Should not happen if enums are synced
    );
  }
}
