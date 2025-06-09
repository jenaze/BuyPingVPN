part of 'split_tunneling_bloc.dart';

// Defines the overall mode for split tunneling
enum SplitTunnelingMode {
  allAppsUseVpn, // All apps use VPN, selected apps are excluded
  onlySelectedAppsUseVpn, // Only selected apps use VPN, others are excluded
}

enum AppListStatus {
  initial,
  loading,
  loaded,
  error,
}

enum SaveStatus {
  idle,
  saving,
  success,
  error,
}

class SplitTunnelingState extends Equatable {
  final AppListStatus appListStatus;
  final List<AppInfo> allApps; // Raw list of all fetched apps
  final List<AppInfo> filteredApps; // Apps currently displayed after filtering
  final Set<String> selectedPackageNames; // Package names of apps selected by the user
  final SplitTunnelingMode currentMode;
  final String? errorMessage; // For app loading errors
  final String? saveErrorMessage; // For saving errors
  final String searchQuery;
  final bool showSystemApps; // To control visibility of system apps
  final bool hasPendingChanges; // True if selections or mode have changed since last save
  final SaveStatus saveStatus; // To give feedback on save operation

  const SplitTunnelingState({
    this.appListStatus = AppListStatus.initial,
    this.allApps = const [],
    this.filteredApps = const [],
    this.selectedPackageNames = const {},
    this.currentMode = SplitTunnelingMode.allAppsUseVpn, // Default mode
    this.errorMessage,
    this.saveErrorMessage,
    this.searchQuery = '',
    this.showSystemApps = false,
    this.hasPendingChanges = false,
    this.saveStatus = SaveStatus.idle,
  });

  SplitTunnelingState copyWith({
    AppListStatus? appListStatus,
    List<AppInfo>? allApps,
    List<AppInfo>? filteredApps,
    Set<String>? selectedPackageNames,
    SplitTunnelingMode? currentMode,
    String? errorMessage,
    String? saveErrorMessage,
    bool clearErrorMessage = false,
    bool clearSaveErrorMessage = false,
    String? searchQuery,
    bool? showSystemApps,
    bool? hasPendingChanges,
    SaveStatus? saveStatus,
  }) {
    return SplitTunnelingState(
      appListStatus: appListStatus ?? this.appListStatus,
      allApps: allApps ?? this.allApps,
      filteredApps: filteredApps ?? this.filteredApps,
      selectedPackageNames: selectedPackageNames ?? this.selectedPackageNames,
      currentMode: currentMode ?? this.currentMode,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      saveErrorMessage: clearSaveErrorMessage ? null : saveErrorMessage ?? this.saveErrorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      showSystemApps: showSystemApps ?? this.showSystemApps,
      hasPendingChanges: hasPendingChanges ?? this.hasPendingChanges,
      saveStatus: saveStatus ?? this.saveStatus,
    );
  }

  @override
  List<Object?> get props => [
        appListStatus,
        allApps,
        filteredApps,
        selectedPackageNames,
        currentMode,
        errorMessage,
        saveErrorMessage,
        searchQuery,
        showSystemApps,
        hasPendingChanges,
        saveStatus,
      ];
}
