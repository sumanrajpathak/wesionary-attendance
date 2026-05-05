import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wesionary_attendance/main.dart';

void main() {
  testWidgets('App renders home screen with tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AttendanceApp());
    await tester.pump();

    expect(find.text('Office Attendance'), findsOneWidget);
    expect(find.text('Mark'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsWidgets);
  });
}
