const weekdayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayNamesUr = [
  '',
  'پیر',
  'منگل',
  'بدھ',
  'جمعرات',
  'جمعہ',
  'ہفتہ',
  'اتوار',
];

String weekdayLabel(int day, String lang) {
  final names = lang == 'ur' ? weekdayNamesUr : weekdayNames;
  if (day < 1 || day > 7) return '';
  return names[day];
}

String formatWhen(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final local = DateTime.tryParse(iso)?.toLocal();
  if (local == null) return '';
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} $hour:$minute';
}

String dueLabel({
  required String status,
  required String? ackDueAt,
  required String? slaDueAt,
  required bool ackBreached,
  required bool slaBreached,
  required String reviewOverdue,
  required String resolveOverdue,
  required String reviewDue,
  required String due,
  required String waiting,
}) {
  if (status == 'submitted') {
    if (ackBreached) return reviewOverdue;
    final left = _remaining(ackDueAt);
    if (left == null) return waiting;
    return '$reviewDue $left';
  }
  if (status == 'closed' ||
      status == 'rejected' ||
      status == 'duplicate' ||
      status == 'resolved') {
    return '';
  }
  if (slaBreached) return resolveOverdue;
  final left = _remaining(slaDueAt);
  if (left == null) return '';
  return '$due $left';
}

String? _remaining(String? iso) {
  if (iso == null) return null;
  final moment = DateTime.tryParse(iso)?.toLocal();
  if (moment == null) return null;
  final delta = moment.difference(DateTime.now());
  if (delta.isNegative) return null;
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  if (delta.inHours < 48) return '${delta.inHours}h';
  return '${delta.inDays}d';
}
