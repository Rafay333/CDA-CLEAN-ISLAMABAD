import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../core/supervisor_api.dart';

class UcArea {
  const UcArea({required this.name, required this.points});

  final String name;
  final List<LatLng> points;

  String get code {
    final match = RegExp(r'UC-\d+(?:-\d+)?').firstMatch(name);
    return match?.group(0) ?? name;
  }

  bool matches(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return true;
    return name.toLowerCase().contains(text) || code.toLowerCase().contains(text);
  }
}

List<UcArea> parseUcXml(String xml) {
  final zones = RegExp(
    r'<zone\b([^>]*)>(.*?)</zone>',
    dotAll: true,
  );
  final nameAttr = RegExp(r'name="([^"]*)"');
  final point = RegExp(
    r'<point\s+lat="(-?[0-9.]+)"\s+lng="(-?[0-9.]+)"\s*/>',
  );
  final areas = <UcArea>[];
  for (final zone in zones.allMatches(xml)) {
    final name = nameAttr.firstMatch(zone.group(1)!)?.group(1) ?? 'UC';
    final points = <LatLng>[
      for (final match in point.allMatches(zone.group(2)!))
        LatLng(double.parse(match.group(1)!), double.parse(match.group(2)!)),
    ];
    if (points.length >= 3) {
      areas.add(UcArea(name: name, points: points));
    }
  }
  return areas;
}

Future<List<UcArea>> loadUcAreas({String? cnic}) async {
  if (cnic != null && cnic.isNotEmpty) {
    final fromApi = await _loadFromApi(cnic);
    if (fromApi.isNotEmpty) return fromApi;
  }
  return _loadFromXml();
}

Future<List<UcArea>> _loadFromApi(String cnic) async {
  final api = SupervisorApi();
  final areas = <UcArea>[];
  for (final zone in const ['Zone-4', 'Zone-5']) {
    try {
      final rows = await api.zoneBoundary(cnic, zone);
      for (final row in rows) {
        final points = [
          for (final point in row.points)
            if (point.lat != 0 || point.lng != 0) LatLng(point.lat, point.lng),
        ];
        if (points.length < 3) continue;
        final name = row.name.trim().isEmpty ? row.ucCode : row.name;
        areas.add(UcArea(name: name, points: points));
      }
    } catch (_) {}
  }
  return areas;
}

Future<List<UcArea>> _loadFromXml() async {
  const files = [
    'test/On_map/Zone-4_UCs.xml',
    'test/On_map/Zone-5_UCs.xml',
  ];
  final areas = <UcArea>[];
  for (final file in files) {
    areas.addAll(parseUcXml(await rootBundle.loadString(file)));
  }
  return areas;
}
