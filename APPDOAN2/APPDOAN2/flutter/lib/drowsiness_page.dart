import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum DrowsyState { idle, normal, drowsy }

class DrowsinessPage extends StatefulWidget {
  const DrowsinessPage({Key? key}) : super(key: key);

  @override
  State<DrowsinessPage> createState() => _DrowsinessPageState();
}

class _DrowsinessPageState extends State<DrowsinessPage> {
  DrowsyState state = DrowsyState.idle;
  String message = "";
  Timer? timer;

  final String baseUrl = "http://10.150.124.111:5000";

  // ================= START AI =================
  Future<void> _start() async {
    await http.post(
      Uri.parse("$baseUrl/ai/start"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "ai_name": "drowsiness",
        "script_path":
            "/home/nhatvu/Desktop/AI_DOAN2/smart_drowsiness_posture/app_drowsiness_posture_onnx_pi.py"
      }),
    );

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _fetchStatus(),
    );
  }

  // ================= STOP AI =================
  Future<void> _stop() async {
    timer?.cancel();

    await http.post(
      Uri.parse("$baseUrl/ai/stop"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ai_name": "drowsiness"}),
    );

    setState(() => state = DrowsyState.idle);
  }

  // ================= FETCH =================
  Future<void> _fetchStatus() async {
    final res =
        await http.get(Uri.parse("$baseUrl/drowsiness/status"));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      setState(() {
        message = data["message"] ?? "";

        if (data["state"] == "drowsy") {
          state = DrowsyState.drowsy;
        } else {
          state = DrowsyState.normal;
        }
      });
    }
  }

  Color _bgColor() {
    switch (state) {
      case DrowsyState.drowsy:
        return Colors.red;
      case DrowsyState.normal:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusText() {
    switch (state) {
      case DrowsyState.drowsy:
        return "⚠️ PHÁT HIỆN NGỦ GẬT";
      case DrowsyState.normal:
        return "BÌNH THƯỜNG";
      default:
        return "Chưa giám sát";
    }
  }

  @override
  Widget build(BuildContext context) {
    Color mainColor;
    IconData icon;
    String title;

    switch (state) {
      case DrowsyState.drowsy:
        mainColor = Colors.red;
        icon = Icons.warning_amber_rounded;
        title = "PHÁT HIỆN NGỦ GẬT";
        break;
      case DrowsyState.normal:
        mainColor = Colors.green;
        icon = Icons.check_circle_outline;
        title = "TRẠNG THÁI BÌNH THƯỜNG";
        break;
      default:
        mainColor = Colors.grey;
        icon = Icons.remove_red_eye_outlined;
        title = "CHƯA GIÁM SÁT";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kiểm tra ngủ gật"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ===== STATUS TEXT =====
            Text(
              state == DrowsyState.idle
                  ? "Sẵn sàng kiểm tra trạng thái học sinh"
                  : "Hệ thống đang giám sát",
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 24),

            // ===== ICON =====
            Icon(
              icon,
              size: 120,
              color: mainColor,
            ),

            const SizedBox(height: 16),

            // ===== TITLE =====
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: mainColor,
              ),
            ),

            const SizedBox(height: 8),

            // ===== MESSAGE =====
            Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 40),

            // ===== START BUTTON =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Bắt đầu giám sát"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: state == DrowsyState.idle ? _start : null,
              ),
            ),

            const SizedBox(height: 16),

            // ===== STOP BUTTON =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text("Dừng giám sát"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: state != DrowsyState.idle ? _stop : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}