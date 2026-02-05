import 'package:flutter/material.dart';
import 'peoplecounter_page.dart';
import 'drowsiness_page.dart';
import 'camera_view_page.dart';

class CameraPage extends StatelessWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Camera"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1️⃣ KIỂM TRA SỐ LƯỢNG HỌC SINH
            ElevatedButton.icon(
              icon: const Icon(Icons.groups),
              label: const Text(
                "Kiểm tra số lượng học sinh",
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PeopleCounterPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // 2️⃣ KIỂM TRA NGỦ GẬT (CHƯA LÀM)
            ElevatedButton.icon(
              icon: const Icon(Icons.visibility_off),
              label: const Text(
                "Kiểm tra ngủ gật",
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DrowsinessPage(),
                  ),
                );
              },

            ),

            const SizedBox(height: 20),

            // 3️⃣ BẬT CAMERA QUAN SÁT (CHƯA LÀM)
            ElevatedButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text("Bật camera quan sát"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CameraViewPage(),
                  ),
                );
              },
            ),

          ],
        ),
      ),
    );
  }
}
