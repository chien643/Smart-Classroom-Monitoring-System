import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'add_face_page.dart';
import 'face_list_page.dart';
import 'history_page.dart';
import 'services/excel_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final String serverUrl = "http://10a.150.124.111:5000";

  // ===== ATTENDANCE STATE =====
  String attendanceState = "idle"; // idle | starting | running | success | error
  String attendanceMessage = "";
  String? attendanceName;

  Timer? statusTimer;
  bool isStarting = false;
  

  @override
  void dispose() {
    statusTimer?.cancel();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Điểm danh khuôn mặt"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== STATUS VIEW =====
            Expanded(
              child: _buildStatusView(),
            ),

            const Divider(),

            // ===== BUTTONS =====
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 24,
              runSpacing: 16,
              children: [
                _buildButton(
                  icon: Icons.play_circle_fill,
                  label: 'Điểm danh',
                  color: Colors.green,
                  onTap: isStarting ? null : _startAttendance,
                ),
                _buildButton(
                  icon: Icons.person_add,
                  label: 'Thêm mặt',
                  color: Colors.blue,
                  onTap: _addFace,
                ),
                _buildButton(
                  icon: Icons.list,
                  label: 'Danh sách',
                  color: Colors.orange,
                  onTap: _openFaceList,
                ),

                // ===== NÚT MỚI: LỊCH SỬ =====
                _buildButton(
                  icon: Icons.history,
                  label: 'Lịch sử',
                  color: Colors.blueGrey,
                  onTap: _openHistory,
                ),
              ],
            ),


            const SizedBox(height: 16),

            if (attendanceState == "running")
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _stopAttendance,
                  icon: const Icon(Icons.stop),
                  label: const Text('DỪNG'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (attendanceState == "starting" || attendanceState == "running")
            const CircularProgressIndicator(),

          const SizedBox(height: 16),

          Text(
            attendanceMessage.isEmpty
                ? "Nhấn 'Điểm danh' để bắt đầu"
                : attendanceMessage,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),

          if (attendanceState == "success" && attendanceName != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                "✅ $attendanceName",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),

          if (attendanceState == "error")
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                "❌ Có lỗi xảy ra",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Column(
      children: [
        Ink(
          decoration: ShapeDecoration(
            color: onTap == null ? Colors.grey : color,
            shape: const CircleBorder(),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            iconSize: 36,
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }

  // ================= LOGIC =================

  Future<void> _startAttendance() async {
    setState(() {
      isStarting = true;
      attendanceState = "starting";
      attendanceMessage = "Đang khởi động hệ thống điểm danh...";
      attendanceName = null;
    });

    final res = await http.post(
      Uri.parse("$serverUrl/ai/start"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "ai_name": "face_attendance",
        "script_path": "app_face_attendance_pi.py",
      }),
    );

    if (res.statusCode != 200) {
      setState(() {
        attendanceState = "error";
        attendanceMessage = "Không khởi động được AI";
        isStarting = false;
      });
      return;
    }

    _startPollingStatus();
  }

  void _startPollingStatus() {
    statusTimer?.cancel();
    statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _fetchAttendanceStatus(),
    );
  }

  Future<void> _fetchAttendanceStatus() async {
    final res = await http.get(
      Uri.parse("$serverUrl/attendance/status"),
    );
    if (res.statusCode != 200) return;

    final data = jsonDecode(res.body);

    final newState = data["state"];
    final newName = data["name"];

    setState(() {
      attendanceState = newState;
      attendanceMessage = data["message"] ?? "";
      attendanceName = newName;
      isStarting = false;
      
    });

    // ✅ BẮT ĐÚNG 1 LẦN SUCCESS
    if (newState == "success" && newName != null) {
      await ExcelService.addHistory(
        newName,
        DateTime.parse(data["timestamp"]),
      );
    }


        if (newState == "success" || newState == "error") {
          statusTimer?.cancel();
        }
      }


  Future<void> _stopAttendance() async {
    await http.post(
      Uri.parse("$serverUrl/ai/stop"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ai_name": "face_attendance"}),
    );

    statusTimer?.cancel();

    setState(() {
      attendanceState = "idle";
      attendanceMessage = "Đã dừng hệ thống";
      attendanceName = null;
    });
  }

  void _addFace() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFacePage()),
    );
  }

  void _openFaceList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FaceListPage()),
    );
  }
  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HistoryPage(),
      ),
    );
  }
}
