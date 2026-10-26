import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';

import 'pakistan_time.dart';

/// Burns a GPS Map Camera–style overlay (map pin + address + lat/lng + time).
Future<Uint8List> stampGpsOnPhoto(
  Uint8List bytes, {
  required String latitude,
  required String longitude,
  String? title,
  DateTime? at,
}) async {
  final lat = double.tryParse(latitude.trim());
  final lng = double.tryParse(longitude.trim());
  if (lat == null || lng == null || bytes.isEmpty) return bytes;

  final when = at ?? pakistanNow();
  final place = await _reverseGeocode(lat, lng);
  final mapBytes = await _mapTile(lat, lng);

  final cityLine = place?.cityLine ?? title?.trim();
  final country = place?.country;
  final address = place?.address;
  final latLong =
      'Lat ${lat.toStringAsFixed(6)}° Long ${lng.toStringAsFixed(6)}°';
  final clock = _formatStampClock(when);
  const note = 'Note: Captured by GPS Map Camera';

  return _drawStamp(
    bytes,
    cityLine: (cityLine == null || cityLine.isEmpty) ? 'Location unavailable' : cityLine,
    countryLine: country == null || country.isEmpty ? null : '$country 🇵🇰',
    address: (address == null || address.isEmpty) ? 'Address unavailable' : address,
    latLong: latLong,
    when: clock,
    note: note,
    mapBytes: mapBytes,
  );
}

Future<Uint8List> _drawStamp(
  Uint8List bytes, {
  required String cityLine,
  required String? countryLine,
  required String address,
  required String latLong,
  required String when,
  required String note,
  Uint8List? mapBytes,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final src = frame.image;
  final w = src.width.toDouble();
  final h = src.height.toDouble();
  if (w < 8 || h < 8) {
    src.dispose();
    return bytes;
  }

  ui.Image? mapImage;
  if (mapBytes != null && mapBytes.isNotEmpty) {
    try {
      final mapCodec = await ui.instantiateImageCodec(mapBytes);
      mapImage = (await mapCodec.getNextFrame()).image;
    } catch (_) {}
  }

  final scale = (w / 1080).clamp(0.55, 2.4);
  final pad = 14.0 * scale;
  final mapSize = 128.0 * scale;
  final textGap = 12.0 * scale;
  final lineGap = 4.0 * scale;
  final hasMap = mapImage != null;
  var textWidth = w - pad * 2 - (hasMap ? mapSize + textGap : 0);
  if (textWidth < 80) textWidth = w * 0.55;

  final titlePainter = _line(cityLine, 26 * scale, bold: true, maxLines: 2);
  final countryPainter = countryLine == null
      ? null
      : _line(countryLine, 20 * scale, bold: true, soft: true);
  final addressPainter = _line(address, 17 * scale, soft: true, maxLines: 2);
  final latPainter = _line(latLong, 18 * scale, bold: true);
  final whenPainter = _line(when, 17 * scale);
  final notePainter = _line(note, 16 * scale, soft: true);
  final badgePainter = _line('GPS Map Camera', 14 * scale, bold: true);

  titlePainter.layout(maxWidth: textWidth);
  countryPainter?.layout(maxWidth: textWidth);
  addressPainter.layout(maxWidth: textWidth);
  latPainter.layout(maxWidth: textWidth);
  whenPainter.layout(maxWidth: textWidth);
  notePainter.layout(maxWidth: textWidth);
  badgePainter.layout();

  var textBlock = titlePainter.height +
      (countryPainter?.height ?? 0) +
      addressPainter.height +
      latPainter.height +
      whenPainter.height +
      notePainter.height +
      lineGap * (countryPainter == null ? 4 : 5);
  var barHeight = math.max(hasMap ? mapSize : 0, textBlock) + pad * 2;
  barHeight = barHeight.clamp(h * 0.16, h * 0.42);
  final barTop = h - barHeight;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(src, Offset.zero, Paint());

  canvas.drawRect(
    Rect.fromLTWH(0, barTop, w, barHeight),
    Paint()..color = const Color(0xB0101418),
  );

  final contentTop = barTop + pad;
  final map = mapImage;
  if (hasMap && map != null) {
    final mapRect = Rect.fromLTWH(pad, contentTop, mapSize, mapSize);
    canvas.save();
    canvas.clipRect(mapRect);
    paintImage(
      canvas: canvas,
      rect: mapRect,
      image: map,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    canvas.restore();
    canvas.drawRect(
      mapRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, scale)
        ..color = const Color(0xB4FFFFFF),
    );
    map.dispose();
  }

  final textX = pad + (hasMap ? mapSize + textGap : 0);
  var y = contentTop;
  titlePainter.paint(canvas, Offset(textX, y));
  y += titlePainter.height + lineGap;
  if (countryPainter != null) {
    countryPainter.paint(canvas, Offset(textX, y));
    y += countryPainter.height + lineGap;
  }
  addressPainter.paint(canvas, Offset(textX, y));
  y += addressPainter.height + lineGap;
  latPainter.paint(canvas, Offset(textX, y));
  y += latPainter.height + lineGap;
  whenPainter.paint(canvas, Offset(textX, y));
  y += whenPainter.height + lineGap;
  notePainter.paint(canvas, Offset(textX, y));

  final badgePadX = 9.0 * scale;
  final badgePadY = 4.0 * scale;
  final boxW = badgePainter.width + badgePadX * 2;
  final boxH = badgePainter.height + badgePadY * 2;
  final boxX = w - boxW - 10 * scale;
  final boxY = (barTop - boxH * 0.55).clamp(6.0, h - boxH);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(boxX, boxY, boxW, boxH),
      Radius.circular(8 * scale),
    ),
    Paint()..color = const Color(0xD2122030),
  );
  badgePainter.paint(canvas, Offset(boxX + badgePadX, boxY + badgePadY));

  final picture = recorder.endRecording();
  final out = await picture.toImage(src.width, src.height);
  src.dispose();
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  out.dispose();
  if (data == null) return bytes;
  return data.buffer.asUint8List();
}

TextPainter _line(
  String text,
  double size, {
  bool bold = false,
  bool soft = false,
  int maxLines = 1,
}) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: soft ? const Color(0xE6ECF0F4) : const Color(0xFFFFFFFF),
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        height: 1.2,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: '…',
  );
}

String _formatStampClock(DateTime local) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final day = days[local.weekday - 1];
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yyyy = local.year.toString();
  var hour = local.hour % 12;
  if (hour == 0) hour = 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour >= 12 ? 'PM' : 'AM';
  return '$day, $dd/$mm/$yyyy $hour:$minute $ampm GMT +05:00';
}

class _Place {
  const _Place({this.address, this.city, this.region, this.country});

  final String? address;
  final String? city;
  final String? region;
  final String? country;

  String get cityLine {
    final parts = [city, region]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty && (country?.trim().isNotEmpty ?? false)) return country!.trim();
    return parts.join(', ');
  }
}

Future<_Place?> _reverseGeocode(double lat, double lng) async {
  try {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        headers: {
          'Accept': 'application/json',
          'Accept-Language': 'en',
          'User-Agent': 'CDA-Clean-Islamabad/1.0 (supervisor tagging)',
        },
      ),
    );
    final response = await dio.get<dynamic>(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'format': 'jsonv2',
        'lat': lat.toStringAsFixed(6),
        'lon': lng.toStringAsFixed(6),
        'addressdetails': 1,
        'accept-language': 'en',
      },
    );
    final data = response.data;
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final addressNode = map['address'];
    final addr = addressNode is Map ? Map<String, dynamic>.from(addressNode) : const <String, dynamic>{};
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = addr[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final display = map['display_name']?.toString().trim();
    return _Place(
      address: display,
      city: pick(const ['city', 'town', 'village', 'municipality', 'county', 'state_district']),
      region: pick(const ['state', 'region', 'state_district']),
      country: pick(const ['country']),
    );
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _mapTile(double lat, double lng) async {
  try {
    const zoom = 16;
    final n = 1 << zoom;
    final x = (lng + 180) / 360 * n;
    final latRad = lat * math.pi / 180;
    final y = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n;
    final tileX = x.floor().clamp(0, n - 1);
    final tileY = y.floor().clamp(0, n - 1);
    final pixelX = ((x - x.floor()) * 256).clamp(0, 255).toDouble();
    final pixelY = ((y - y.floor()) * 256).clamp(0, 255).toDouble();

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        responseType: ResponseType.bytes,
        headers: {
          'User-Agent': 'CDA-Clean-Islamabad/1.0 (supervisor tagging)',
        },
      ),
    );
    final response = await dio.get<List<int>>(
      'https://tile.openstreetmap.org/$zoom/$tileX/$tileY.png',
    );
    final raw = response.data;
    if (raw == null || raw.isEmpty) return null;
    return await _annotatePin(Uint8List.fromList(raw), pixelX, pixelY);
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _annotatePin(Uint8List png, double pixelX, double pixelY) async {
  try {
    final codec = await ui.instantiateImageCodec(png);
    final tile = (await codec.getNextFrame()).image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(tile, Offset.zero, Paint());
    final size = math.max(8.0, tile.width / 18.0);
    final pin = Paint()..color = const Color(0xDCDC1C1C);
    final cx = pixelX;
    final cy = pixelY;
    canvas.drawCircle(Offset(cx, cy - size * 0.7), size * 0.45, pin);
    final path = Path()
      ..moveTo(cx - size * 0.38, cy - size * 0.45)
      ..lineTo(cx + size * 0.38, cy - size * 0.45)
      ..lineTo(cx, cy + size * 0.35)
      ..close();
    canvas.drawPath(path, pin);
    canvas.drawCircle(
      Offset(cx, cy - size * 0.8),
      size * 0.16,
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final picture = recorder.endRecording();
    final out = await picture.toImage(tile.width, tile.height);
    tile.dispose();
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return png;
  }
}
