var SPREADSHEET_ID = '1RIGHJlkxMDK53whMYGkNa-WbVwF9W__Oi9pB935s3YI';
var EMPLOYEE_SHEET = 'Employees';
var EMPLOYEE_HEADERS = ['ID', 'Name', 'Email', 'Role', 'Password'];
var MONTH_HEADERS = ['Employee ID', 'Employee Name'];
var MONTH_TOTAL_HEADER = 'Total Present';
var MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
var ROLE_ADMIN = 'admin';
var ROLE_USER = 'user';

function doGet(e) {
  try {
    var action = (e && e.parameter && e.parameter.action) || '';
    switch (action) {
      case 'getEmployees':
        return jsonOk({ data: getEmployees() });
      case 'getAttendance':
        return jsonOk({
          data: getAttendance(e.parameter.month, e.parameter.employeeId),
        });
      case 'ping':
        return jsonOk({ pong: true });
      default:
        return jsonError('Unknown action: ' + action);
    }
  } catch (err) {
    return jsonError(err.message || String(err));
  }
}

function doPost(e) {
  try {
    var body = {};
    if (e && e.postData && e.postData.contents) {
      body = JSON.parse(e.postData.contents);
    }
    var action = body.action || '';
    switch (action) {
      case 'login':
        return jsonOk({ user: login(body) });
      case 'markAttendance':
        requireAdmin_(body.adminEmail);
        return jsonOk({ count: markAttendance(body.records || []) });
      default:
        return jsonError('Unknown action: ' + action);
    }
  } catch (err) {
    return jsonError(err.message || String(err));
  }
}

function getEmployeeSheet_() {
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(EMPLOYEE_SHEET);
  if (!sheet) {
    sheet = ss.insertSheet(EMPLOYEE_SHEET);
  }
  ensureHeaders_(sheet, EMPLOYEE_HEADERS);
  return sheet;
}

function ensureHeaders_(sheet, headers) {
  if (sheet.getLastRow() === 0) {
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.setFrozenRows(1);
  }
}

function readEmployees_() {
  var sheet = getEmployeeSheet_();
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return [];
  var values = sheet.getRange(2, 1, lastRow - 1, EMPLOYEE_HEADERS.length).getValues();
  var out = [];
  for (var i = 0; i < values.length; i++) {
    var row = values[i];
    var id = String(row[0] || '').trim();
    var name = String(row[1] || '').trim();
    var email = String(row[2] || '').trim().toLowerCase();
    var role = String(row[3] || '').trim().toLowerCase() || ROLE_USER;
    var password = String(row[4] || '');
    if (!id && !name && !email) continue;
    out.push({ id: id, name: name, email: email, role: role, password: password });
  }
  return out;
}

function getEmployees() {
  return readEmployees_().map(function (e) {
    return { id: e.id, name: e.name, email: e.email, role: e.role };
  });
}

function findEmployeeByEmail_(email) {
  var target = String(email || '').trim().toLowerCase();
  if (!target) return null;
  var employees = readEmployees_();
  for (var i = 0; i < employees.length; i++) {
    if (employees[i].email === target) return employees[i];
  }
  return null;
}

function login(body) {
  var method = String(body.method || '').toLowerCase();
  if (method === 'admin') {
    var email = String(body.email || '').trim();
    var password = String(body.password || '');
    if (!email || !password) throw new Error('Email and password required.');
    var emp = findEmployeeByEmail_(email);
    if (!emp) throw new Error('No account for that email.');
    if (emp.role !== ROLE_ADMIN) throw new Error('Not an admin account.');
    var stored = String(emp.password || '');
    if (looksHashed_(stored)) {
      if (!verifyPassword_(password, stored)) throw new Error('Wrong password.');
    } else {
      // Legacy plaintext row — accept once, then upgrade to hashed in place.
      if (stored !== password) throw new Error('Wrong password.');
      writePasswordHash_(emp.email, makePasswordHash_(password));
    }
    return publicEmployee_(emp);
  }
  if (method === 'google') {
    var gEmail = String(body.email || '').trim();
    if (!gEmail) throw new Error('Google email required.');
    var match = findEmployeeByEmail_(gEmail);
    if (!match) throw new Error('Your Google account is not in the Employees list.');
    return publicEmployee_(match);
  }
  throw new Error('Unknown login method: ' + method);
}

function publicEmployee_(e) {
  return { id: e.id, name: e.name, email: e.email, role: e.role };
}

function requireAdmin_(email) {
  var emp = findEmployeeByEmail_(email);
  if (!emp || emp.role !== ROLE_ADMIN) {
    throw new Error('Admin authentication required.');
  }
  return emp;
}

function ensureMonthHeaders_(sheet) {
  if (sheet.getLastRow() === 0) {
    var headers = MONTH_HEADERS.concat([MONTH_TOTAL_HEADER]);
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.setFrozenRows(1);
    sheet.setFrozenColumns(MONTH_HEADERS.length);
  }
}

function isMonthSheetName_(name) {
  for (var i = 0; i < MONTH_NAMES.length; i++) {
    if (MONTH_NAMES[i] === name) return true;
  }
  return false;
}

function getAttendance(month, employeeIdFilter) {
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheets;
  if (month) {
    var s = ss.getSheetByName(month);
    sheets = s ? [s] : [];
  } else {
    sheets = ss.getSheets().filter(function (sh) {
      return isMonthSheetName_(sh.getName());
    });
  }

  var filterId = employeeIdFilter ? String(employeeIdFilter) : '';
  var tz = Session.getScriptTimeZone();
  var out = [];
  for (var i = 0; i < sheets.length; i++) {
    var sheet = sheets[i];
    var lastRow = sheet.getLastRow();
    var lastCol = sheet.getLastColumn();
    if (lastRow < 2 || lastCol < MONTH_HEADERS.length + 1) continue;

    var values = sheet.getRange(1, 1, lastRow, lastCol).getValues();
    var header = values[0];

    for (var c = MONTH_HEADERS.length; c < lastCol; c++) {
      var dateCell = header[c];
      var dateStr = '';
      if (dateCell instanceof Date) {
        dateStr = Utilities.formatDate(dateCell, tz, 'yyyy-MM-dd');
      } else if (dateCell) {
        dateStr = String(dateCell);
      }
      if (!dateStr) continue;
      if (dateStr === MONTH_TOTAL_HEADER) continue;

      for (var r = 1; r < lastRow; r++) {
        var row = values[r];
        var id = String(row[0] || '');
        var name = String(row[1] || '');
        if (!id && !name) continue;
        if (filterId && id !== filterId) continue;
        var raw = String(row[c] || '').trim().toUpperCase();
        if (!raw) continue;
        var status = raw === 'P' ? 'present' : 'absent';
        out.push({
          employeeId: id,
          employeeName: name,
          date: dateStr,
          status: status,
          time: '',
        });
      }
    }
  }
  return out;
}

function markAttendance(records) {
  if (!records || !records.length) return 0;
  var grouped = {};
  for (var i = 0; i < records.length; i++) {
    var r = records[i];
    if (!r || !r.date) continue;
    var d = new Date(r.date);
    var monthName = Utilities.formatDate(d, Session.getScriptTimeZone(), 'MMMM');
    if (!grouped[monthName]) grouped[monthName] = [];
    grouped[monthName].push(r);
  }

  var total = 0;
  for (var month in grouped) {
    total += writeMonth_(month, grouped[month]);
  }
  return total;
}

function writeMonth_(monthName, records) {
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(monthName);
  if (!sheet) sheet = ss.insertSheet(monthName);
  ensureMonthHeaders_(sheet);

  var lastRow = sheet.getLastRow();
  var lastCol = sheet.getLastColumn();
  if (lastCol < MONTH_HEADERS.length + 1) lastCol = MONTH_HEADERS.length + 1;

  var headerValues = sheet.getRange(1, 1, 1, lastCol).getValues()[0];

  var totalCol = -1;
  for (var c = 0; c < headerValues.length; c++) {
    if (headerValues[c] === MONTH_TOTAL_HEADER) { totalCol = c + 1; break; }
  }
  if (totalCol === -1) {
    totalCol = lastCol + 1;
    sheet.getRange(1, totalCol).setValue(MONTH_TOTAL_HEADER);
  }

  var tz = Session.getScriptTimeZone();
  var dateColMap = {};
  for (var c = MONTH_HEADERS.length; c < totalCol - 1; c++) {
    var h = headerValues[c];
    if (!h) continue;
    var key = (h instanceof Date)
      ? Utilities.formatDate(h, tz, 'yyyy-MM-dd')
      : String(h);
    dateColMap[key] = c + 1;
  }

  var empRowMap = {};
  if (lastRow >= 2) {
    var idValues = sheet.getRange(2, 1, lastRow - 1, MONTH_HEADERS.length).getValues();
    for (var r = 0; r < idValues.length; r++) {
      var id = String(idValues[r][0] || '');
      if (id) empRowMap[id] = r + 2;
    }
  }

  var nextRow = lastRow + 1;
  if (nextRow < 2) nextRow = 2;

  for (var i = 0; i < records.length; i++) {
    var rec = records[i];
    var dateStr = String(rec.date);

    if (!dateColMap[dateStr]) {
      sheet.insertColumnBefore(totalCol);
      sheet.getRange(1, totalCol).setValue(dateStr);
      dateColMap[dateStr] = totalCol;
      totalCol += 1;
    }

    if (!empRowMap[rec.employeeId]) {
      sheet.getRange(nextRow, 1, 1, MONTH_HEADERS.length)
        .setValues([[rec.employeeId, rec.employeeName || '']]);
      empRowMap[rec.employeeId] = nextRow;
      nextRow++;
    }

    var statusRaw = String(rec.status || '').toLowerCase();
    var cellValue = (statusRaw === 'present' || statusRaw === 'p') ? 'P' : 'A';
    sheet.getRange(empRowMap[rec.employeeId], dateColMap[dateStr]).setValue(cellValue);
  }

  refreshTotals_(sheet, totalCol);
  return records.length;
}

function refreshTotals_(sheet, totalCol) {
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return;
  var firstDateCol = MONTH_HEADERS.length + 1;
  if (totalCol <= firstDateCol) return;
  var formula = '=COUNTIF(R[0]C' + firstDateCol + ':R[0]C[-1],"P")';
  sheet.getRange(2, totalCol, lastRow - 1, 1).setFormulaR1C1(formula);
}

function jsonOk(payload) {
  var body = { success: true };
  for (var k in payload) body[k] = payload[k];
  return ContentService.createTextOutput(JSON.stringify(body))
    .setMimeType(ContentService.MimeType.JSON);
}

function jsonError(message) {
  return ContentService.createTextOutput(
    JSON.stringify({ success: false, error: message })
  ).setMimeType(ContentService.MimeType.JSON);
}

// Stored password format: "<salt-hex>:<sha256-hex>" where the digest is taken
// over (salt + ':' + password). UUID-derived salt gives 128 bits of entropy.
function looksHashed_(value) {
  return /^[0-9a-f]+:[0-9a-f]{64}$/i.test(String(value || ''));
}

function makePasswordHash_(password) {
  var salt = Utilities.getUuid().replace(/-/g, '');
  return salt + ':' + sha256Hex_(salt + ':' + password);
}

function verifyPassword_(password, stored) {
  var parts = String(stored || '').split(':');
  if (parts.length !== 2) return false;
  var expected = parts[1];
  var actual = sha256Hex_(parts[0] + ':' + password);
  return constantTimeEquals_(expected, actual);
}

function sha256Hex_(input) {
  var bytes = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    input,
    Utilities.Charset.UTF_8
  );
  var hex = '';
  for (var i = 0; i < bytes.length; i++) {
    var b = bytes[i] < 0 ? bytes[i] + 256 : bytes[i];
    var h = b.toString(16);
    hex += h.length === 1 ? '0' + h : h;
  }
  return hex;
}

function constantTimeEquals_(a, b) {
  if (a.length !== b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function writePasswordHash_(email, hash) {
  var sheet = getEmployeeSheet_();
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return;
  var emails = sheet.getRange(2, 3, lastRow - 1, 1).getValues();
  var target = String(email || '').trim().toLowerCase();
  for (var i = 0; i < emails.length; i++) {
    if (String(emails[i][0] || '').trim().toLowerCase() === target) {
      sheet.getRange(i + 2, 5).setValue(hash);
      return;
    }
  }
}

// Run this once from the Apps Script editor after deploying to hash any
// existing plaintext passwords in the Employees sheet. Safe to re-run —
// rows already in salt:hash form are skipped.
function migratePasswordsToHashes() {
  var sheet = getEmployeeSheet_();
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return 0;
  var range = sheet.getRange(2, 5, lastRow - 1, 1);
  var values = range.getValues();
  var changed = 0;
  for (var i = 0; i < values.length; i++) {
    var v = String(values[i][0] || '');
    if (!v) continue;
    if (looksHashed_(v)) continue;
    values[i][0] = makePasswordHash_(v);
    changed++;
  }
  if (changed > 0) range.setValues(values);
  return changed;
}
