import 'package:flutter/material.dart';

import 'mqtt_service.dart';
import 'control_page.dart';
import 'attendance_page.dart';
import 'camera_page.dart';
import 'services/excel_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ❌ KHÔNG await MQTT → tránh treo app khi không có Pi / khác wifi
  MqttService().connect();

  // ✅ ÉP KHỞI TẠO FILE EXCEL NGAY KHI APP CHẠY
  await ExcelService.loadClassSize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Classroom',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final pages = const [
    ControlPage(),
    AttendancePage(),
    CameraPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.toggle_on),
            label: "Công tắc",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "Điểm danh",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            label: "Camera",
          ),
        ],
      ),
    );
  }
}
