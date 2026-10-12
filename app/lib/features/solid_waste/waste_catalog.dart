/// Lookup lists for the solid waste forms.
///
/// Activities, zones, union councils, container types, and TCP names are
/// empty until the real lists are added. Screens only read these values.
class WasteCatalog {
  const WasteCatalog._();

  static const activities = <String>[];

  static const zones = <String>[];

  static const containerTypes = <String>[];

  static const containerTagging = 'Tagging of Containers';

  static const transferModes = <String>['Vehicle trips', 'Zero Waste'];

  static const picturesPerUc = 2;

  static const unlimitedActivities = <String>{};

  static bool allowsUnlimitedPictures(String? activity) {
    return activity != null && unlimitedActivities.contains(activity);
  }

  /// Null means the activity accepts any number of pictures.
  static int? pictureLimit(String? activity) {
    if (allowsUnlimitedPictures(activity)) return null;
    return picturesPerUc;
  }

  static const zone4Ucs = <String>[];

  static const zone5Ucs = <String>[];

  static final List<String> allUcs = List<String>.of(zone4Ucs)
    ..addAll(zone5Ucs)
    ..sort((a, b) => _ucNumber(a).compareTo(_ucNumber(b)));

  static List<String> ucsFor(String? zone) {
    return switch (zone) {
      'Zone-4' => zone4Ucs,
      'Zone-5' => zone5Ucs,
      _ => const <String>[],
    };
  }

  static const tcpNames = <String>[];

  static int _ucNumber(String label) {
    final hyphen = label.indexOf('-');
    final space = label.indexOf(' ');
    if (hyphen < 0 || space <= hyphen) return 0;
    return int.tryParse(label.substring(hyphen + 1, space)) ?? 0;
  }
}
