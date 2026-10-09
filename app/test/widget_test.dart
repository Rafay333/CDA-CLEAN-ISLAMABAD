import 'package:cda_clean_islamabad/core/format.dart';
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

  test('weekday labels stay in Monday-first order', () {
    expect(weekdayLabel(1, 'en'), 'Mon');
    expect(weekdayLabel(1, 'ur'), 'پیر');
  });
}
