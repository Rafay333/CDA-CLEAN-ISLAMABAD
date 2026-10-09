class UserAccount {
  const UserAccount({
    required this.id,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.language,
    this.sectorId,
    this.zoneId,
    this.employeeId,
  });

  final String id;
  final String role;
  final String fullName;
  final String phone;
  final String language;
  final String? sectorId;
  final String? zoneId;
  final String? employeeId;

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: '${json['id']}',
      role: '${json['role']}',
      fullName: '${json['fullName'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      language: '${json['language'] ?? 'en'}',
      sectorId: json['sectorId'] as String?,
      zoneId: json['zoneId'] as String?,
      employeeId: json['employeeId'] as String?,
    );
  }
}

class Sector {
  const Sector({
    required this.id,
    required this.code,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    this.zoneId,
  });

  final String id;
  final String code;
  final String name;
  final double centerLat;
  final double centerLng;
  final String? zoneId;

  factory Sector.fromJson(Map<String, dynamic> json) {
    return Sector(
      id: '${json['id']}',
      code: '${json['code']}',
      name: '${json['name'] ?? json['code']}',
      centerLat: _num(json['centerLat']),
      centerLng: _num(json['centerLng']),
      zoneId: json['zoneId'] as String?,
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameUr,
  });

  final String id;
  final String code;
  final String nameEn;
  final String nameUr;

  String name(String lang) => lang == 'ur' ? nameUr : nameEn;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: '${json['id']}',
      code: '${json['code']}',
      nameEn: '${json['nameEn']}',
      nameUr: '${json['nameUr']}',
    );
  }
}

class CasePhoto {
  const CasePhoto({required this.id, required this.kind, required this.path});
  final String id;
  final String kind;
  final String path;

  factory CasePhoto.fromJson(Map<String, dynamic> json) {
    return CasePhoto(
      id: '${json['id']}',
      kind: '${json['kind']}',
      path: '${json['path']}',
    );
  }
}

class CaseEvent {
  const CaseEvent({
    required this.id,
    this.toStatus,
    this.note,
    this.at,
    this.actorLabel,
  });
  final String id;
  final String? toStatus;
  final String? note;
  final String? at;
  final String? actorLabel;

  factory CaseEvent.fromJson(Map<String, dynamic> json) {
    return CaseEvent(
      id: '${json['id']}',
      toStatus: json['toStatus'] as String?,
      note: json['note'] as String?,
      at: json['at'] as String?,
      actorLabel: json['actorLabel'] as String?,
    );
  }
}

class CleanCase {
  const CleanCase({
    required this.id,
    required this.caseNumber,
    required this.status,
    required this.categoryCode,
    required this.categoryEn,
    required this.categoryUr,
    required this.sectorId,
    required this.sectorCode,
    required this.zoneName,
    required this.streetText,
    required this.latitude,
    required this.longitude,
    required this.ackBreached,
    required this.slaBreached,
    this.categoryId,
    this.description,
    this.ackDueAt,
    this.slaDueAt,
    this.rejectionReason,
    this.duplicateOfNumber,
    this.reporterName,
    this.reporterPhone,
    this.createdAt,
    this.photos = const [],
    this.events = const [],
  });

  final String id;
  final String caseNumber;
  final String status;
  final String? categoryId;
  final String categoryCode;
  final String categoryEn;
  final String categoryUr;
  final String sectorId;
  final String sectorCode;
  final String zoneName;
  final String streetText;
  final String? description;
  final double latitude;
  final double longitude;
  final String? ackDueAt;
  final String? slaDueAt;
  final bool ackBreached;
  final bool slaBreached;
  final String? rejectionReason;
  final String? duplicateOfNumber;
  final String? reporterName;
  final String? reporterPhone;
  final String? createdAt;
  final List<CasePhoto> photos;
  final List<CaseEvent> events;

  String category(String lang) => lang == 'ur' ? categoryUr : categoryEn;

  factory CleanCase.fromJson(Map<String, dynamic> json) {
    final category = Map<String, dynamic>.from(json['category'] as Map? ?? {});
    final sector = Map<String, dynamic>.from(json['sector'] as Map? ?? {});
    final zone = Map<String, dynamic>.from(json['zone'] as Map? ?? {});
    final photos = (json['photos'] as List? ?? [])
        .map(
          (item) => CasePhoto.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final events = (json['events'] as List? ?? [])
        .map(
          (item) => CaseEvent.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return CleanCase(
      id: '${json['id']}',
      caseNumber: '${json['caseNumber']}',
      status: '${json['status']}',
      categoryId: category['id'] as String?,
      categoryCode: '${category['code'] ?? ''}',
      categoryEn: '${category['nameEn'] ?? ''}',
      categoryUr: '${category['nameUr'] ?? ''}',
      sectorId: '${sector['id'] ?? ''}',
      sectorCode: '${sector['code'] ?? ''}',
      zoneName: '${zone['name'] ?? ''}',
      streetText: '${json['streetText'] ?? ''}',
      description: json['description'] as String?,
      latitude: _num(json['latitude']),
      longitude: _num(json['longitude']),
      ackDueAt: json['ackDueAt'] as String?,
      slaDueAt: json['slaDueAt'] as String?,
      ackBreached: json['ackBreached'] == true,
      slaBreached: json['slaBreached'] == true,
      rejectionReason: json['rejectionReason'] as String?,
      duplicateOfNumber: json['duplicateOfNumber'] as String?,
      reporterName: json['reporterName'] as String?,
      reporterPhone: json['reporterPhone'] as String?,
      createdAt: json['createdAt'] as String?,
      photos: photos,
      events: events,
    );
  }
}

class MapPin {
  const MapPin({
    required this.id,
    required this.categoryCode,
    required this.status,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String categoryCode;
  final String status;
  final double latitude;
  final double longitude;

  factory MapPin.fromJson(Map<String, dynamic> json) {
    return MapPin(
      id: '${json['id']}',
      categoryCode: '${json['categoryCode'] ?? ''}',
      status: '${json['status'] ?? ''}',
      latitude: _num(json['latitude']),
      longitude: _num(json['longitude']),
    );
  }
}

class StreetBeat {
  const StreetBeat({
    required this.name,
    required this.days,
    required this.windowStart,
    required this.windowEnd,
  });
  final String name;
  final List<int> days;
  final String windowStart;
  final String windowEnd;

  factory StreetBeat.fromJson(Map<String, dynamic> json) {
    return StreetBeat(
      name: '${json['name']}',
      days: (json['days'] as List? ?? [])
          .map((day) => int.tryParse('$day') ?? 0)
          .toList(),
      windowStart: '${json['windowStart']}',
      windowEnd: '${json['windowEnd']}',
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.caseId,
    this.createdAt,
  });
  final String id;
  final String title;
  final String body;
  final String? caseId;
  final String? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: '${json['id']}',
      title: '${json['title']}',
      body: '${json['body']}',
      caseId: json['caseId'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class OfficerOption {
  const OfficerOption({
    required this.id,
    required this.fullName,
    required this.openJobs,
  });
  final String id;
  final String fullName;
  final int openJobs;

  factory OfficerOption.fromJson(Map<String, dynamic> json) {
    return OfficerOption(
      id: '${json['id']}',
      fullName: '${json['fullName']}',
      openJobs: json['openJobs'] is num ? (json['openJobs'] as num).toInt() : 0,
    );
  }
}

class StaffMember {
  const StaffMember({
    required this.id,
    required this.fullName,
    required this.employeeId,
    required this.role,
    required this.status,
    this.zoneName,
  });

  final String id;
  final String fullName;
  final String employeeId;
  final String role;
  final String status;
  final String? zoneName;

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: '${json['id']}',
      fullName: '${json['fullName']}',
      employeeId: '${json['employeeId'] ?? ''}',
      role: '${json['role']}',
      status: '${json['status']}',
      zoneName: json['zoneName'] as String?,
    );
  }
}

class CityStats {
  const CityStats({
    required this.openCases,
    required this.breached,
    required this.filedToday,
    required this.zones,
    this.medianResolveHours,
  });

  final int openCases;
  final int breached;
  final int filedToday;
  final double? medianResolveHours;
  final List<ZoneStat> zones;

  factory CityStats.fromJson(Map<String, dynamic> json) {
    return CityStats(
      openCases: _int(json['openCases']),
      breached: _int(json['breached']),
      filedToday: _int(json['filedToday']),
      medianResolveHours: json['medianResolveHours'] is num
          ? (json['medianResolveHours'] as num).toDouble()
          : null,
      zones: (json['zones'] as List? ?? [])
          .map(
            (item) => ZoneStat.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class ZoneStat {
  const ZoneStat({required this.name, required this.openCases});
  final String name;
  final int openCases;

  factory ZoneStat.fromJson(Map<String, dynamic> json) {
    return ZoneStat(
      name: '${json['name']}',
      openCases: _int(json['openCases']),
    );
  }
}

double _num(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
