part of 'split_tunneling_bloc.dart';

abstract class SplitTunnelingEvent extends Equatable {
  const SplitTunnelingEvent();

  @override
  List<Object?> get props => [];
}

// Event to trigger the initial loading of saved settings and the app list
class InitializeSplitTunneling extends SplitTunnelingEvent {
  final bool initialShowSystemApps; // User preference for showing system apps, could be from global settings
  final bool fetchAppIcons; // Whether to fetch icons initially

  const InitializeSplitTunneling({
    this.initialShowSystemApps = false,
    this.fetchAppIcons = true,
  });

   @override
  List<Object?> get props => [initialShowSystemApps, fetchAppIcons];
}


// Event to load the list of installed applications (can be re-triggered by filters)
class LoadInstalledApps extends SplitTunnelingEvent {
  final bool includeSystemApps;
  final bool includeAppIcons;

  const LoadInstalledApps({
    required this.includeSystemApps,
    required this.includeAppIcons,
  });

  @override
  List<Object?> get props => [includeSystemApps, includeAppIcons];
}

// Event to toggle the selection state of an application
class ToggleAppSelection extends SplitTunnelingEvent {
  final String packageName;
  const ToggleAppSelection(this.packageName);

  @override
  List<Object?> get props => [packageName];
}

// Event to change the overall split tunneling mode
class ChangeSplitTunnelingMode extends SplitTunnelingEvent {
  final SplitTunnelingMode mode;
  const ChangeSplitTunnelingMode(this.mode);

  @override
  List<Object?> get props => [mode];
}

// Event to save the current split tunneling rules
class SaveSplitTunnelingRules extends SplitTunnelingEvent {}

// Event to update the search query for filtering apps
class UpdateAppSearchQuery extends SplitTunnelingEvent {
  final String query;
  const UpdateAppSearchQuery(this.query);

  @override
  List<Object?> get props => [query];
}

// Event to toggle the visibility of system apps (triggers LoadInstalledApps)
class ToggleSystemAppsVisibility extends SplitTunnelingEvent {
   final bool showSystemApps;
   const ToggleSystemAppsVisibility({required this.showSystemApps});

    @override
    List<Object?> get props => [showSystemApps];
}

// Internal event to update state after settings are loaded from persistence
class _SettingsLoaded extends SplitTunnelingEvent {
  final SplitTunnelingSettings loadedSettings;
  const _SettingsLoaded(this.loadedSettings);

  @override
  List<Object?> get props => [loadedSettings];
}
