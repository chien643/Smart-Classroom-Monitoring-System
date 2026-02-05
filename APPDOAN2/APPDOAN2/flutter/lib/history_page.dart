import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'services/excel_service.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int classSize = 0;
  List<Map<String, String>> history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 🔁 Reload mỗi lần mở lại page
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    classSize = await ExcelService.loadClassSize();
    history = await ExcelService.loadHistory();
    if (mounted) {
      setState(() {});
    }
  }

  // ✅ ĐẾM CÓ MẶT THEO NGÀY HÔM NAY (KHÔNG TRÙNG TÊN)
  String get today {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  int get attendedToday =>
      history.where((h) => h['date'] == today).length;

  int get absentToday =>
      classSize > attendedToday ? classSize - attendedToday : 0;


  // ================= NHẬP SĨ SỐ =================
  void _inputClassSize() {
    final ctrl = TextEditingController(text: classSize.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nhập sĩ số lớp'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: 45',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(ctrl.text);
              if (val != null) {
                await ExcelService.saveClassSize(val);
                classSize = val;   // 🔥 cập nhật ngay
                setState(() {});   // 🔥 ép UI refresh
              }
              Navigator.pop(context);
            },

            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  // ================= HIỂN THỊ ĐƯỜNG DẪN FILE =================
  Future<void> _showExcelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đường dẫn file Excel'),
        content: Text('${dir.path}/attendance_history.xlsx'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
  Future<void> _openExcelFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/attendance_history.xlsx');

    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có file Excel')),
      );
      return;
    }

    await OpenFilex.open(file.path);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử điểm danh'),
        actions: [
          // 🔥 NÚT MỞ FILE EXCEL
          IconButton(
            icon: const Icon(Icons.table_view),
            tooltip: 'Mở file Excel',
            onPressed: _openExcelFile,
          ),

          // ✏️ NÚT NHẬP SĨ SỐ
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Nhập sĩ số',
            onPressed: _inputClassSize,
          ),
        ],
      ),

      body: Column(
        children: [
          // ===== THỐNG KÊ =====
          Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.people),
              title: Text('Sĩ số: $classSize'),
              subtitle: Text(
                'Có mặt hôm nay: $attendedToday | Vắng: $absentToday',
              ),
            ),
          ),

          // ===== DANH SÁCH =====
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có dữ liệu điểm danh',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (_, i) {
                      final h = history[i];
                      return ListTile(
                        leading: Text('${i + 1}'),
                        title: Text(h['name'] ?? ''),
                        subtitle:
                            Text('${h['date']} - ${h['time']}'),
                        trailing: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
