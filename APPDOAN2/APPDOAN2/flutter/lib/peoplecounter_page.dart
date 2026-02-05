import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/excel_service.dart';

enum CounterState { idle, starting, running }

class PeopleCounterPage extends StatefulWidget {
  const PeopleCounterPage({Key? key}) : super(key: key);

  @override
  State<PeopleCounterPage> createState() => _PeopleCounterPageState();
}

class _PeopleCounterPageState extends State<PeopleCounterPage> {
  int currentCount = 0;
  int classSize = 0;
  CounterState state = CounterState.idle;
  Timer? timer;

  final String baseUrl = "http://10.150.124.111:5000";

  @override
  void initState() {
    super.initState();
    _loadClassSize();
  }

  // ================= LOAD CLASS SIZE =================
  Future<void> _loadClassSize() async {
    classSize = await ExcelService.loadClassSize();
    setState(() {});
  }

  // ================= START AI =================
  Future<void> _startCounter() async {
    setState(() => state = CounterState.starting);

    await http.post(
      Uri.parse("$baseUrl/ai/start"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "ai_name": "people_counter",
        "script_path":
            "/home/nhatvu/Desktop/AI_DOAN2/counter_people/onnx_people_counter_speed.py"
      }),
    );

    timer?.cancel();
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _fetchCount(),
    );

    setState(() => state = CounterState.running);
  }

  // ================= STOP AI =================
  Future<void> _stopCounter() async {
    timer?.cancel();

    await http.post(
      Uri.parse("$baseUrl/ai/stop"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "ai_name": "people_counter",
      }),
    );

    setState(() {
      state = CounterState.idle;
      currentCount = 0;
    });
  }

  // ================= FETCH COUNT =================
  Future<void> _fetchCount() async {
    try {
      final res =
          await http.get(Uri.parse("$baseUrl/people_counter/status"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          currentCount = data["count"] ?? 0;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  // ================= UI =================
  String _statusText() {
    switch (state) {
      case CounterState.starting:
        return "Đang khởi động camera...";
      case CounterState.running:
        return "Đang kiểm tra số lượng học sinh";
      case CounterState.idle:
      default:
        return "Sẵn sàng kiểm tra";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kiểm tra số lượng học sinh"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ===== STATUS =====
            Text(
              _statusText(),
              style: TextStyle(
                fontSize: 16,
                color: state == CounterState.running
                    ? Colors.green
                    : Colors.orange,
              ),
            ),

            const SizedBox(height: 24),

            // ===== COUNT =====
            Text(
              "$currentCount / $classSize",
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 32),

            // ===== START BUTTON =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  "Bắt đầu kiểm tra",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed:
                    state == CounterState.idle ? _startCounter : null,
              ),
            ),

            const SizedBox(height: 16),

            // ===== STOP BUTTON =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text(
                  "Dừng",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed:
                    state == CounterState.running ? _stopCounter : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
