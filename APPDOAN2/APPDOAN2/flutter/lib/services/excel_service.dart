import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class ExcelService {
  static const String _fileName = "attendance_history.xlsx";

  // ================= FILE =================
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');

    // 🔥 CHỈ TẠO FILE 1 LẦN DUY NHẤT
    if (!file.existsSync()) {
      final excel = Excel.createExcel();

      final info = excel['ClassInfo'];
      info.appendRow(['class_size']);
      info.appendRow([0]);

      file.writeAsBytesSync(excel.encode()!);
    }

    return file;
  }

  // ================= SĨ SỐ =================
  static Future<void> saveClassSize(int size) async {
    final file = await _getFile();
    final excel = Excel.decodeBytes(file.readAsBytesSync());

    final sheet = excel['ClassInfo'];

    // 🔥 GHI ĐÈ HOÀN TOÀN
    sheet.rows.clear();
    sheet.appendRow(['class_size']);
    sheet.appendRow([size]);

    file.writeAsBytesSync(excel.encode()!);
  }

  static Future<int> loadClassSize() async {
    final file = await _getFile();
    final excel = Excel.decodeBytes(file.readAsBytesSync());

    if (!excel.sheets.containsKey('ClassInfo')) return 0;

    final sheet = excel['ClassInfo'];

    // 🔥 LẤY DÒNG CUỐI CÙNG CÓ GIÁ TRỊ
    for (int i = sheet.rows.length - 1; i >= 0; i--) {
      final cell = sheet.rows[i][0]?.value;
      if (cell != null) {
        final v = int.tryParse(cell.toString());
        if (v != null) return v;
      }
    }

    return 0;
  }


  // ================= HISTORY (1 SHEET / NGÀY) =================
  static Future<void> addHistory(String name, DateTime time) async {
    final file = await _getFile();
    final excel = Excel.decodeBytes(file.readAsBytesSync());

    // 📅 TÊN SHEET = NGÀY
    final sheetName =
        '${time.year.toString().padLeft(4, '0')}-'
        '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')}';

    // 📄 LẤY / TẠO SHEET NGÀY
    Sheet sheet;
    if (excel.sheets.containsKey(sheetName)) {
      sheet = excel[sheetName];
    } else {
      sheet = excel[sheetName];
      sheet.appendRow(['STT', 'Tên', 'Giờ vào']);
    }

    // 🚫 CHỐNG TRÙNG TÊN TRONG CÙNG NGÀY
    for (int i = 1; i < sheet.rows.length; i++) {
      final existingName =
          sheet.rows[i][1]?.value?.toString() ?? '';
      if (existingName == name) {
        file.writeAsBytesSync(excel.encode()!);
        return;
      }
    }

    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';

    sheet.appendRow([
      sheet.rows.length,
      name,
      timeStr,
    ]);

    file.writeAsBytesSync(excel.encode()!);
  }

  // ================= LOAD HISTORY =================
  static Future<List<Map<String, String>>> loadHistory() async {
    final file = await _getFile();
    final excel = Excel.decodeBytes(file.readAsBytesSync());

    final List<Map<String, String>> list = [];

    for (final sheetName in excel.sheets.keys) {
      // ❌ BỎ QUA SHEET KHÔNG PHẢI NGÀY
      if (sheetName == 'ClassInfo') continue;
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(sheetName)) continue;

      final sheet = excel[sheetName]!;

      for (int i = 1; i < sheet.rows.length; i++) {
        final name =
            sheet.rows[i][1]?.value?.toString() ?? '';
        final time =
            sheet.rows[i][2]?.value?.toString() ?? '';

        // 🚫 BỎ QUA HEADER / DÒNG RÁC
        if (name.toLowerCase() == 'tên' ||
            time.toLowerCase().contains('giờ')) {
          continue;
        }

        list.add({
          'name': name,
          'date': sheetName,
          'time': time,
        });
      }
    }

    // 🔥 SẮP XẾP MỚI NHẤT LÊN TRÊN
    list.sort((a, b) {
      return '${b['date']} ${b['time']}'
          .compareTo('${a['date']} ${a['time']}');
    });

    return list;
  }
}
