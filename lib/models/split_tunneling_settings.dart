import 'package:equatable/equatable.dart';

// Re-use the enum from the BLoC state or define it here if it's more global
// For this example, let's assume it's defined here or in a common place.
enum SplitTunnelingMode {
  allAppsUseVpn,
  onlySelectedAppsUseVpn,
}

class SplitTunnelingSettings extends Equatable {
  final SplitTunnelingMode mode;
  final Set<String> selectedPackageNames;

  const SplitTunnelingSettings({
    this.mode = SplitTunnelingMode.allAppsUseVpn, // Default mode
    this.selectedPackageNames = const {},
  });

  SplitTunnelingSettings copyWith({
    SplitTunnelingMode? mode,
    Set<String>? selectedPackageNames,
  }) {
    return SplitTunnelingSettings(
      mode: mode ?? this.mode,
      selectedPackageNames: selectedPackageNames ?? this.selectedPackageNames,
    );
  }

  @override
  List<Object?> get props => [mode, selectedPackageNames];
}
