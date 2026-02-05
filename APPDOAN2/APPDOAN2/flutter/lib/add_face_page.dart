import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:convert';

class AddFacePage extends StatefulWidget {
  const AddFacePage({super.key});

  @override
  State<AddFacePage> createState() => _AddFacePageState();
}

class _AddFacePageState extends State<AddFacePage> {
  final String serverUrl = "http://10.150.124.111:5000";
  final TextEditingController nameCtrl = TextEditingController();

  CameraController? camCtrl;
  List<CameraDescription>? cams;

  bool personReady = false;
  String? currentPerson;
  int imageCount = 0; // số ảnh hiện tại

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    cams = await availableCameras();
    if (cams != null && cams!.isNotEmpty) {
      camCtrl = CameraController(
        cams![0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await camCtrl!.initialize();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    camCtrl?.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFull = imageCount >= 5;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Thêm khuôn mặt"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ===== CAMERA VIEW =====
            Expanded(
              child: Container(
                color: Colors.black,
                child: camCtrl == null || !camCtrl!.value.isInitialized
                    ? const Center(child: CircularProgressIndicator())
                    : CameraPreview(camCtrl!),
              ),
            ),
            const SizedBox(height: 12),

            // ===== NAME INPUT =====
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "Tên học sinh (tên thư mục)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),

            // ===== STATUS =====
            if (personReady)
              Text(
                isFull
                    ? "Đã đủ 5/5 ảnh – không thể chụp thêm"
                    : "Sẵn sàng chụp: $imageCount / 5 ảnh",
                style: TextStyle(
                  color: isFull ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),

            const SizedBox(height: 12),

            // ===== BUTTONS =====
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _createOrCheckPerson(context),
                    child: const Text("TẠO / KIỂM TRA"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: personReady && !isFull
                        ? () => _captureImage(context)
                        : null,
                    child: Text(isFull ? "ĐÃ ĐỦ 5/5" : "CHỤP ẢNH"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ===== CLOSE =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("ĐÓNG"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= LOGIC =================

  /// Tạo person nếu chưa có + kiểm tra số ảnh hiện tại
  Future<void> _createOrCheckPerson(BuildContext ctx) async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final r = await http.post(
      Uri.parse("$serverUrl/person/create"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"name": name}),
    );

    if (r.statusCode == 200) {
      currentPerson = name;
      await _checkImageCount(name);

      setState(() {
        personReady = true;
      });

      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            imageCount >= 5
                ? "Thư mục đã đủ 5/5 ảnh"
                : "Sẵn sàng chụp ($imageCount/5)",
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text("Lỗi tạo / tìm thư mục")),
      );
    }
  }

  /// Kiểm tra số ảnh hiện có
  Future<void> _checkImageCount(String name) async {
    final res = await http.get(
      Uri.parse("$serverUrl/images/list?name=$name"),
    );

    if (res.statusCode == 200) {
      final imgs = List<String>.from(jsonDecode(res.body));
      imageCount = imgs.length;
    } else {
      imageCount = 0;
    }
  }

  /// Chụp và upload ảnh
  Future<void> _captureImage(BuildContext ctx) async {
    if (camCtrl == null || !camCtrl!.value.isInitialized) return;
    if (imageCount >= 5) return;

    try {
      final img = await camCtrl!.takePicture();
      final file = File(img.path);

      var req = http.MultipartRequest(
        'POST',
        Uri.parse("$serverUrl/person/capture"),
      );
      req.fields['name'] = currentPerson!;
      req.files.add(
        await http.MultipartFile.fromPath('image', file.path),
      );

      final res = await req.send();

      if (res.statusCode == 200) {
        await _checkImageCount(currentPerson!);
        setState(() {});
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text("Đã lưu ảnh ($imageCount/5)")),
        );
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text("Không lưu được ảnh")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text("Lỗi camera: $e")),
      );
    }
  }
}
