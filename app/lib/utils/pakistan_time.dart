/// Pakistan Standard Time is UTC+05:00 year-round (no DST).
const Duration pakistanOffset = Duration(hours: 5);

/// Current instant expressed as a wall-clock DateTime in Asia/Karachi.
DateTime pakistanNow() {
  final utc = DateTime.now().toUtc();
  final pkt = utc.add(pakistanOffset);
  return DateTime(pkt.year, pkt.month, pkt.day, pkt.hour, pkt.minute, pkt.second, pkt.millisecond);
}

/// Format [instant] as ISO-8601 with an explicit `+05:00` offset.
///
/// If [instant] is a "naive" Pakistan wall time (from [pakistanNow] or a frozen
/// resolve time), it is treated as Asia/Karachi. UTC values are converted first.
String toPakistanIso(DateTime instant) {
  final pkt = instant.isUtc
      ? instant.add(pakistanOffset)
      : instant;
  final y = pkt.year.toString().padLeft(4, '0');
  final m = pkt.month.toString().padLeft(2, '0');
  final d = pkt.day.toString().padLeft(2, '0');
  final h = pkt.hour.toString().padLeft(2, '0');
  final min = pkt.minute.toString().padLeft(2, '0');
  final s = pkt.second.toString().padLeft(2, '0');
  return '$y-$m-$d'
      'T$h:$min:$s+05:00';
}

/// Parse a Pakistan ISO string (or any ISO-8601) into a naive Asia/Karachi wall clock.
DateTime? parsePakistanDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) return null;
  final pkt = parsed.toUtc().add(pakistanOffset);
  return DateTime(
    pkt.year,
    pkt.month,
    pkt.day,
    pkt.hour,
    pkt.minute,
    pkt.second,
    pkt.millisecond,
  );
}
