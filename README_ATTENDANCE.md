# Office Attendance

Flutter app that records employee attendance into a Google Sheet via a Google Apps Script backend.

- **Sheet1** — attendance log (one row per present employee per day)
- **Sheet2** — employee master list

Spreadsheet: `1RIGHJlkxMDK53whMYGkNa-WbVwF9W__Oi9pB935s3YI`

## Project layout

```
lib/
├── main.dart
├── models/
│   ├── employee.dart
│   └── attendance_record.dart
├── providers/
│   └── attendance_provider.dart
├── services/
│   └── sheets_api_service.dart
└── screens/
    ├── home_screen.dart
    ├── mark_attendance_screen.dart
    ├── history_screen.dart
    └── settings_screen.dart
google_apps_script/
└── Code.gs
```

## Quick start

1. Deploy `google_apps_script/Code.gs` as a Web app (see [SETUP_GUIDE.md](SETUP_GUIDE.md)).
2. `flutter pub get && flutter run`
3. Open **Settings** in the app, paste the `/exec` URL.
4. Mark attendance.

## How data flows

- **App → Sheet1**: `markAttendance` POST appends rows.
- **Sheet2 → App**: `getEmployees` GET reads the master list every refresh.
- **Sheet1 → App**: `getAttendance` GET hydrates the History tab.

The local `SharedPreferences` cache keeps the last-seen employee list and history so the UI loads instantly between sessions.
