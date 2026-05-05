# Setup Guide

This app uses a tiny **Google Apps Script** as its backend. No service-account JSON, no OAuth client setup — just a one-time deploy.

The spreadsheet is hard-coded to:
`https://docs.google.com/spreadsheets/d/1RIGHJlkxMDK53whMYGkNa-WbVwF9W__Oi9pB935s3YI/edit`

**Sheet1** = attendance log (append-only).
**Sheet2** = employee master list.

## 1. Deploy the Apps Script (one time)

1. Open the spreadsheet above.
2. **Extensions → Apps Script.**
3. Replace the contents of `Code.gs` with [google_apps_script/Code.gs](google_apps_script/Code.gs) from this repo. Save.
4. **Deploy → New deployment**.
   - Type: **Web app**
   - Execute as: **Me**
   - Who has access: **Anyone**
5. Authorize the script when prompted (Google will warn it's unverified — proceed for your own script).
6. Copy the **Web app URL** that ends in `/exec`.

## 2. Seed Sheet2 (employees)

In **Sheet2**, the first row is headers `ID | Name`. The script auto-creates them on first call. Add rows like:

| ID  | Name        |
| --- | ----------- |
| 001 | Suman P.    |
| 002 | Anita K.    |

You can also add employees from inside the app (top-right ➕ icon).

## 3. Run the app

```bash
flutter pub get
flutter run
```

On first launch, open **Settings** (gear icon, top-right) and paste the `/exec` URL. The app pulls employees from Sheet2 and shows them on the Mark tab.

## 4. Use it

- **Mark** tab: pick the date, tick employees, **Submit attendance**. Rows append to Sheet1.
- **History** tab: pulls Sheet1 grouped by date.
- **Pull-to-refresh** on either tab re-syncs from the sheet.
- Records stay cached locally so the UI is responsive offline; submission requires connectivity.

## Sheet schemas

**Sheet1 — attendance log**

| Employee ID | Employee Name | Date       | Status  | Time  |
| ----------- | ------------- | ---------- | ------- | ----- |
| 001         | Suman P.      | 2026-04-29 | present | 09:14 |

**Sheet2 — employees**

| ID  | Name     |
| --- | -------- |
| 001 | Suman P. |

## Troubleshooting

- **`Unexpected response from Apps Script`** — your deployment is set to "Execute as: User accessing the web app" or "Who has access: Only myself". Redeploy with **Me / Anyone**.
- **Empty employee list** — Sheet2 has only the header row. Add rows or use the in-app ➕ button.
- **`HTTP 401/403`** — re-authorize the deployment (Apps Script asks once per Google account).
- Apps Script web apps are rate-limited; bulk imports of thousands of rows aren't this app's job.
