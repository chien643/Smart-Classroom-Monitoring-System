import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

class CameraViewPage extends StatefulWidget {
  const CameraViewPage({Key? key}) : super(key: key);

  @override
  State<CameraViewPage> createState() => _CameraViewPageState();
}

class _CameraViewPageState extends State<CameraViewPage> {
  final String baseUrl = "http://10.150.124.111:5000";
  late final WebViewController controller;
  bool isCameraOn = false;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  // ================= START CAMERA =================
  Future<void> _startCamera() async {
    await http.get(Uri.parse("$baseUrl/camera/start"));
    controller.loadRequest(Uri.parse("$baseUrl/video_feed"));
    setState(() => isCameraOn = true);
  }

  // ================= STOP CAMERA =================
  Future<void> _stopCamera() async {
    await http.get(Uri.parse("$baseUrl/camera/stop"));
    setState(() => isCameraOn = false);
  }

  @override
  void dispose() {
    _stopCamera(); // 🔥 THOÁT LÀ TẮT CAM
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Camera giám sát"),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: isCameraOn
                  ? AspectRatio(
                      aspectRatio: 4 / 3, // đúng với 640x480
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: WebViewWidget(controller: controller),
                      ),
                    )
                  : const Text("Camera đang tắt"),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.videocam),
                    label: const Text("Bật camera"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: isCameraOn ? null : _startCamera,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.videocam_off),
                    label: const Text("Tắt camera"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: isCameraOn ? _stopCamera : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
