import 'package:cda_clean_islamabad/core/format.dart';
import 'package:cda_clean_islamabad/core/staff_access.dart';
import 'package:cda_clean_islamabad/core/supervisor_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a submitted report past its review time is marked overdue', () {
    expect(
      dueLabel(
        status: 'submitted',
        ackDueAt: null,
        slaDueAt: null,
        ackBreached: true,
        slaBreached: false,
        reviewOverdue: 'Review overdue',
        resolveOverdue: 'Resolve overdue',
        reviewDue: 'Review due',
        due: 'Due',
        waiting: 'Waiting',
      ),
      'Review overdue',
    );
  });

  test('login capabilities gate modules without using the role name', () {
    final helper = SupervisorUser.fromJson({
      'userId': 1,
      'cnic': '3520212345671',
      'role': 'Helper',
      'roleLabel': 'Helper',
      'capabilities': ['login', 'serve_containers'],
    });
    expect(helper.can(StaffCapability.login), isTrue);
    expect(helper.can(StaffCapability.serveContainers), isTrue);
    expect(helper.can(StaffCapability.resolveIssues), isFalse);
    expect(helper.can(StaffCapability.markAttendance), isFalse);
    expect(helper.can(StaffCapability.submitEvidence), isFalse);
    expect(helper.can(StaffCapability.manageHr), isFalse);
    expect(helper.allowsPath('/waste/activity'), isTrue);
    expect(helper.allowsPath('/waste/tagging'), isFalse);
    expect(helper.allowsPath('/complaints'), isFalse);
    expect(helper.allowsPath('/hr1/attendance'), isFalse);

    final legacy = SupervisorUser.fromJson({'userId': 2, 'cnic': '3520212345671'});
    expect(legacy.can(StaffCapability.manageHr), isTrue);
    expect(legacy.allowsPath('/complaints'), isTrue);
  });

  test('weekday labels stay in Monday-first order', () {
    expect(weekdayLabel(1, 'en'), 'Mon');
    expect(weekdayLabel(1, 'ur'), 'پیر');
  });
}
