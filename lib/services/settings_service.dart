import 'package:shared_preferences/shared_preferences.dart';
import 'package:your_app_name/models/split_tunneling_settings.dart'; // Assuming path
import 'dart:convert'; // For potential future use if storing complex objects, not strictly needed for List<String>

class SettingsService {
  static const String _splitTunnelingModeKey = 'split_tunneling_mode';
  static const String _selectedAppsKey = 'split_tunneling_selected_apps';

  Future<void> saveSplitTunnelingSettings(SplitTunnelingSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_splitTunnelingModeKey, settings.mode.toString());
    await prefs.setStringList(_selectedAppsKey, settings.selectedPackageNames.toList());
    print('SettingsService: Saved split tunneling mode: ${settings.mode}');
    print('SettingsService: Saved selected apps: ${settings.selectedPackageNames.length} apps');
  }

  Future<SplitTunnelingSettings> loadSplitTunnelingSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load mode
    final String? modeString = prefs.getString(_splitTunnelingModeKey);
    SplitTunnelingMode mode = SplitTunnelingMode.allAppsUseVpn; // Default
    if (modeString != null) {
      try {
        mode = SplitTunnelingMode.values.firstWhere((e) => e.toString() == modeString);
      } catch (e) {
        // Handle error or corrupted data, fallback to default
        print('SettingsService: Error parsing saved mode string: $modeString. Using default.');
      }
    }

    // Load selected apps
    final List<String>? packageNamesList = prefs.getStringList(_selectedAppsKey);
    Set<String> selectedPackageNames = {};
    if (packageNamesList != null) {
      selectedPackageNames = packageNamesList.toSet();
    }

    print('SettingsService: Loaded split tunneling mode: $mode');
    print('SettingsService: Loaded selected apps: ${selectedPackageNames.length} apps');

    return SplitTunnelingSettings(
      mode: mode,
      selectedPackageNames: selectedPackageNames,
    );
  }

  // Example of how SplitTunnelingBloc might use this:
  // In SplitTunnelingBloc constructor or an init event:
  //   _settingsService.loadSplitTunnelingSettings().then((settings) {
  //     // Update BLoC state with loaded settings
  //     add(UpdateSplitTunnelingSettingsEvent(settings)); // Assuming such an event exists
  //   });

  // In SplitTunnelingBloc when SaveSplitTunnelingRules event occurs:
  //   await _settingsService.saveSplitTunnelingSettings(
  //     SplitTunnelingSettings(
  //       mode: state.currentMode,
  //       selectedPackageNames: state.selectedPackageNames,
  //     )
  //   );
}
