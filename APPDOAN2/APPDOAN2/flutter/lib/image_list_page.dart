import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ImageListPage extends StatefulWidget {
  final String personName;

  const ImageListPage({Key? key, required this.personName}) : super(key: key);

  @override
  State<ImageListPage> createState() => _ImageListPageState();
}

class _ImageListPageState extends State<ImageListPage> {
  final String serverUrl = "http://10.150.124.111:5000";
  List<String> images = [];
  bool isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  // ===== LOAD ẢNH (API CŨ – ĐANG CHẠY) =====
  Future<void> _loadImages() async {
    setState(() => isLoading = true);

    final res = await http.get(
      Uri.parse("$serverUrl/images/list?name=${widget.personName}"),
    );

    setState(() {
      images = List<String>.from(jsonDecode(res.body));
      isLoading = false;
    });
  }

  // ===== THÊM ẢNH (GIỚI HẠN 5) =====
  Future<void> _addImage() async {
    if (images.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mỗi thư mục chỉ được tối đa 5 ảnh"),
        ),
      );
      return;
    }

    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    var request = http.MultipartRequest(
      'POST',
      Uri.parse("$serverUrl/images/add"),
    );

    request.fields['name'] = widget.personName;
    request.files.add(
      await http.MultipartFile.fromPath('image', picked.path),
    );

    await request.send();
    _loadImages();
  }

  // ===== XOÁ ẢNH =====
  Future<void> _deleteImage(String imageName) async {
    await http.get(
      Uri.parse(
        "$serverUrl/images/delete"
        "?name=${widget.personName}&image=$imageName",
      ),
    );
    _loadImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ảnh - ${widget.personName}"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addImage,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: images.length,
              itemBuilder: (_, i) {
                final img = images[i];
                return GestureDetector(
                  onTap: () => _deleteImage(img),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          "$serverUrl/faces/${widget.personName}/$img",
                          fit: BoxFit.cover,
                        ),
                      ),
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
