import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'image_list_page.dart';

class FaceListPage extends StatefulWidget {
  const FaceListPage({Key? key}) : super(key: key);

  @override
  State<FaceListPage> createState() => _FaceListPageState();
}

class _FaceListPageState extends State<FaceListPage> {
  final String serverUrl = "http://10.150.124.111:5000";

  List<String> faces = [];
  Map<String, int> imageCountMap = {}; // lưu số ảnh mỗi person

  @override
  void initState() {
    super.initState();
    _loadFaces();
  }

  Future<void> _loadFaces() async {
    final res = await http.get(Uri.parse("$serverUrl/person/list"));
    final list = List<String>.from(jsonDecode(res.body));

    setState(() {
      faces = list;
    });

    // load số ảnh cho từng person
    for (final name in list) {
      _loadImageCount(name);
    }
  }

  Future<void> _loadImageCount(String name) async {
    final res = await http.get(
      Uri.parse("$serverUrl/images/list?name=$name"),
    );

    if (res.statusCode == 200) {
      final imgs = List<String>.from(jsonDecode(res.body));
      setState(() {
        imageCountMap[name] = imgs.length;
      });
    } else {
      setState(() {
        imageCountMap[name] = 0;
      });
    }
  }

  Future<void> _deleteFace(String name) async {
    await http.get(
      Uri.parse("$serverUrl/person/delete?name=$name"),
    );
    _loadFaces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Danh sách khuôn mặt"),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: faces.length,
        itemBuilder: (_, i) {
          final name = faces[i];
          final count = imageCountMap[name];

          return ListTile(
            leading: const Icon(Icons.folder),
            title: Text(name),
            subtitle: Text(
              count == null ? "Đang tải..." : "$count / 5 ảnh",
              style: TextStyle(
                color: count != null && count >= 5
                    ? Colors.red
                    : Colors.grey,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteFace(name),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageListPage(personName: name),
                ),
              ).then((_) {
                // reload số ảnh khi quay lại
                _loadImageCount(name);
              });
            },
          );
        },
      ),
    );
  }
}
