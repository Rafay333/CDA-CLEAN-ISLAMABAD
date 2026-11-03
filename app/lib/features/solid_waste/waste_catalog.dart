import '../../core/supervisor_api.dart';
import '../complaints/uc_boundaries.dart';

/// Lookup lists for the solid waste forms.
///
/// Loaded from `GET /api/supervisor/catalog`. Zone/UC XML is the fallback.
class WasteCatalog {
  const WasteCatalog._();

  static const containerTagging = 'Tagging of Containers';
  static const picturesPerUc = 2;

  /// Tagging + Activity inventory sizes (old 2-option list).
  static const inventoryContainerTypes = <String>[
    '1.1 m3',
    '8 m3',
  ];

  /// Alias used by tagging screen.
  static const defaultTaggingContainerTypes = inventoryContainerTypes;

  static SupervisorCatalog _catalog = const SupervisorCatalog();
  static List<UcArea> _areas = const [];
  static var _loaded = false;

  static SupervisorCatalog get data => _catalog;

  static List<String> get zones {
    if (_catalog.zones.isNotEmpty) return [for (final zone in _catalog.zones) zone.code];
    return const ['Zone-4', 'Zone-5'];
  }

  /// Inventory sizes for Activity / Tagging (`1.1 m3` / `8 m3`).
  static List<String> get containerTypes {
    final fromCatalog = [
      for (final t in _catalog.containerTypes)
        if (_looksLikeInventorySize(t)) t,
    ];
    return fromCatalog.isEmpty ? inventoryContainerTypes : fromCatalog;
  }

  /// Same 2 options for tagging (do not use Open/Skip).
  static List<String> get taggingContainerTypes => containerTypes;

  static bool _looksLikeInventorySize(String value) {
    final v = value.trim().toLowerCase();
    return v.contains('m3') || v.contains('m³');
  }

  static List<String> get vehicleTypes => _catalog.vehicleTypes;
  static List<CatalogVehicle> get vehicles => _catalog.vehicles;
  static List<CatalogActivity> get activities => _catalog.activities;
  static List<CatalogLocation> get locations => _catalog.locations;

  static bool allowsUnlimitedPictures(String? activity) {
    for (final item in _catalog.activities) {
      if (item.name == activity || item.code == activity) return item.unlimitedPictures;
    }
    return false;
  }

  static int? pictureLimit(String? activity) {
    if (allowsUnlimitedPictures(activity)) return null;
    for (final item in _catalog.activities) {
      if (item.name == activity || item.code == activity) return item.pictureLimitPerUc;
    }
    return picturesPerUc;
  }

  static Future<void> ensureLoaded({String? cnic, bool force = false}) async {
    if (_loaded && !force) return;
    if (cnic != null && cnic.isNotEmpty) {
      try {
        _catalog = await SupervisorApi().catalog(cnic);
        _loaded = true;
        if (_catalog.ucs.isNotEmpty) return;
      } catch (_) {}
    }
    _areas = await loadUcAreas(cnic: cnic);
    _loaded = true;
  }

  static List<String> get allUcs {
    if (_catalog.ucs.isNotEmpty) {
      return [for (final uc in _catalog.ucs) uc.code];
    }
    final seen = <String>{};
    final list = <String>[];
    for (final area in _areas) {
      if (seen.add(area.code)) list.add(area.code);
    }
    list.sort((a, b) => _ucNumber(a).compareTo(_ucNumber(b)));
    return list;
  }

  /// Display labels for UC dropdowns (name when available, else code).
  static List<String> get allUcLabels {
    if (_catalog.ucs.isNotEmpty) {
      return [for (final uc in _catalog.ucs) _ucLabel(uc)];
    }
    return allUcs;
  }

  static String? ucCodeForLabel(String? label) {
    if (label == null || label.isEmpty) return null;
    for (final uc in _catalog.ucs) {
      if (_ucLabel(uc) == label || uc.code == label || uc.name == label) return uc.code;
    }
    for (final code in allUcs) {
      if (code == label) return code;
    }
    return label;
  }

  static String? ucLabelForCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final uc in _catalog.ucs) {
      if (uc.code == code) return _ucLabel(uc);
    }
    return code;
  }

  static String _ucLabel(CatalogUc uc) {
    final name = uc.name.trim();
    if (name.isEmpty || name == uc.code) return uc.code;
    return name;
  }

  static List<String> ucsFor(String? zone) {
    if (zone == null || zone.isEmpty) return const [];
    if (_catalog.ucs.isNotEmpty) {
      return [
        for (final uc in _catalog.ucs)
          if (uc.zoneCode == zone) uc.code,
      ];
    }
    final prefix = switch (zone) {
      'Zone-4' => 'zone 4',
      'Zone-5' => 'zone 5',
      _ => zone.toLowerCase(),
    };
    final seen = <String>{};
    final list = <String>[];
    for (final area in _areas) {
      if (!area.name.toLowerCase().contains(prefix)) continue;
      if (seen.add(area.code)) list.add(area.code);
    }
    list.sort((a, b) => _ucNumber(a).compareTo(_ucNumber(b)));
    return list;
  }

  static List<CatalogLocation> locationsFor(String? uc) {
    if (uc == null || uc.isEmpty) return _catalog.locations;
    return [for (final place in _catalog.locations) if (place.ucCode == null || place.ucCode == uc) place];
  }

  static int _ucNumber(String label) {
    final match = RegExp(r'UC-(\d+)').firstMatch(label);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
