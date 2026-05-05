import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

String buildCsv(List<List<String>> rows) {
  final buf = StringBuffer();
  for (final row in rows) {
    buf.writeln(row.map(_escape).join(','));
  }
  return buf.toString();
}

String _escape(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
  return value;
}

Future<void> shareCsv({
  required String filename,
  required String content,
  String? subject,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          bytes,
          name: filename,
          mimeType: 'text/csv',
        ),
      ],
      subject: subject,
      fileNameOverrides: [filename],
    ),
  );
}
