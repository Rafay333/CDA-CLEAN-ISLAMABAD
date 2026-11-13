/// Capability codes returned by login, activate, `/me`, and the gap profile.
/// Screens check these codes. They do not branch on role names.
abstract final class StaffCapability {
  static const login = 'login';
  static const serveContainers = 'serve_containers';
  static const resolveIssues = 'resolve_issues';
  static const markAttendance = 'mark_attendance';
  static const submitEvidence = 'submit_evidence';
  static const manageHr = 'manage_hr';

  /// What a supervisor receives today. Used only when an older login payload
  /// has no role and no capability list.
  static const all = <String>[
    login,
    serveContainers,
    resolveIssues,
    markAttendance,
    submitEvidence,
    manageHr,
  ];
}

List<String> readCapabilityList(Object? raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if ((item?.toString().trim() ?? '').isNotEmpty) item.toString().trim(),
    ];
  }
  return const [];
}

/// Missing list + missing role = legacy supervisor (full access).
/// A role with no list = login only, so a partial payload cannot unlock modules.
List<String> capabilitiesFromJson(Map<String, dynamic> json) {
  if (json.containsKey('capabilities')) return readCapabilityList(json['capabilities']);
  final role = _optional(json['role']);
  final roleLabel = _optional(json['roleLabel']) ?? _optional(json['role_label']);
  if (role != null || roleLabel != null) return const [StaffCapability.login];
  return StaffCapability.all;
}

String staffRoleLabel(Map<String, dynamic> json) {
  return _optional(json['roleLabel']) ?? _optional(json['role_label']) ?? _optional(json['role']) ?? '';
}

bool isContainerClearanceActivity({required String code, required String name}) {
  final normalized = code.trim().toLowerCase();
  if (normalized == 'containers') return true;
  final label = name.trim().toLowerCase();
  return label == 'container collection/clearance' || label.startsWith('container collection');
}

String? _optional(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null') return null;
  return text;
}
