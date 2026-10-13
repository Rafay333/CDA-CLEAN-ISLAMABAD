import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supervisor_api.dart';
import '../utils/pakistan_time.dart';

/// One complaint resolve waiting to upload when the device is back online.
class PendingResolve {
  const PendingResolve({
    required this.id,
    required this.issueId,
    required this.cnic,
    required this.resolvedAtIso,
    required this.photoPaths,
    this.notes,
    this.resolvedByName,
  });

  final String id;
  final int issueId;
  final String cnic;
  /// Frozen Asia/Karachi resolve time, e.g. `2026-10-13T20:00:00+05:00`.
  final String resolvedAtIso;
  final List<String> photoPaths;
  final String? notes;
  final String? resolvedByName;

  DateTime get resolvedAt =>
      parsePakistanDateTime(resolvedAtIso) ?? pakistanNow();

  Map<String, dynamic> toJson() => {
        'id': id,
        'issueId': issueId,
        'cnic': cnic,
        'resolvedAtIso': resolvedAtIso,
        'photoPaths': photoPaths,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (resolvedByName != null && resolvedByName!.isNotEmpty)
          'resolvedByName': resolvedByName,
      };

  factory PendingResolve.fromJson(Map<String, dynamic> json) {
    final paths = json['photoPaths'];
    return PendingResolve(
      id: json['id'] as String,
      issueId: (json['issueId'] as num).toInt(),
      cnic: json['cnic'] as String,
      resolvedAtIso: json['resolvedAtIso'] as String,
      photoPaths: paths is List
          ? [for (final p in paths) p.toString()]
          : const [],
      notes: json['notes'] as String?,
      resolvedByName: json['resolvedByName'] as String?,
    );
  }

  Future<List<UploadPhoto>> loadPhotos() async {
    final uploads = <UploadPhoto>[];
    for (var i = 0; i < photoPaths.length; i++) {
      final file = File(photoPaths[i]);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      uploads.add(UploadPhoto(bytes: bytes, filename: 'after$i.jpg'));
    }
    return uploads;
  }
}

class PendingResolveStore {
  PendingResolveStore._();

  static const _prefsKey = 'pendingComplaintResolves';

  static Future<Directory> _photoDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/pending_resolves');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<List<PendingResolve>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            PendingResolve.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<int> count() async => (await list()).length;

  static Future<void> _save(List<PendingResolve> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([for (final item in items) item.toJson()]),
    );
  }

  /// Persist photos and metadata. [resolvedAtIso] must already be frozen.
  static Future<PendingResolve> enqueue({
    required int issueId,
    required String cnic,
    required String resolvedAtIso,
    required List<Uint8List> photoBytes,
    List<String?>? photoFilenames,
    String? notes,
    String? resolvedByName,
  }) async {
    final id =
        '${issueId}_${DateTime.now().toUtc().millisecondsSinceEpoch}';
    final dir = await _photoDir();
    final itemDir = Directory('${dir.path}/$id');
    await itemDir.create(recursive: true);

    final paths = <String>[];
    for (var i = 0; i < photoBytes.length; i++) {
      final bytes = photoBytes[i];
      if (bytes.isEmpty) continue;
      final name = _safeFileName(photoFilenames?[i], i);
      final file = File('${itemDir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      paths.add(file.path);
    }
    if (paths.isEmpty) {
      await itemDir.delete(recursive: true);
      throw StateError('No after photos to queue.');
    }

    final item = PendingResolve(
      id: id,
      issueId: issueId,
      cnic: cnic,
      resolvedAtIso: resolvedAtIso,
      photoPaths: paths,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      resolvedByName:
          resolvedByName?.trim().isEmpty == true ? null : resolvedByName?.trim(),
    );

    final items = await list();
    final replaced = items.where((existing) => existing.issueId == issueId).toList();
    items.removeWhere((existing) => existing.issueId == issueId);
    for (final old in replaced) {
      await _deleteItemFiles(old);
    }
    items.add(item);
    await _save(items);
    return item;
  }

  static Future<void> remove(String id) async {
    final items = await list();
    final match = items.where((item) => item.id == id).toList();
    items.removeWhere((item) => item.id == id);
    await _save(items);
    for (final item in match) {
      await _deleteItemFiles(item);
    }
  }

  static Future<void> clearAll() async {
    final items = await list();
    await _save(const []);
    for (final item in items) {
      await _deleteItemFiles(item);
    }
  }

  static Future<void> _deleteItemFiles(PendingResolve item) async {
    try {
      if (item.photoPaths.isEmpty) return;
      final parent = File(item.photoPaths.first).parent;
      if (await parent.exists()) {
        await parent.delete(recursive: true);
      }
    } catch (_) {}
  }

  static String _safeFileName(String? name, int index) {
    final trimmed = name?.trim() ?? '';
    final lower = trimmed.toLowerCase();
    const allowed = ['.jpg', '.jpeg', '.png', '.webp'];
    if (allowed.any(lower.endsWith)) {
      return trimmed.replaceAll(RegExp(r'[^\w.\-]'), '_');
    }
    return 'after$index.jpg';
  }
}
