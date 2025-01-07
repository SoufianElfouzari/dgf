import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import 'package:baustellenapp/DataBase/appwrite_constant.dart';

class CameraScreen extends StatefulWidget {
  final Client client;
  const CameraScreen({super.key, required this.client});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
    );

    await _controller.initialize();
  }

  Future<String?> _uploadAndSendImage(File imageFile) async {
    try {
      Uint8List imageBytes = await imageFile.readAsBytes();
      Storage storage = Storage(widget.client);
      final result = await storage.createFile(
        bucketId: AppwriteConstants.storageBucketId,
        fileId: 'unique()', // Erzeuge eine eindeutige Datei-ID
        file: InputFile(
          bytes: imageBytes,
          filename: 'camera_image.png',
        ),
      );

      // Erstelle die Bild-URL
      String imageUrl = '${AppwriteConstants.endPoint}/storage/buckets/${AppwriteConstants.storageBucketId}/files/${result.$id}/view?project=${AppwriteConstants.projectId}';

      return imageUrl; // Gebe die Bild-URL zurück
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Hochladen: $e')),
      );
      return null; // Gebe null zurück, wenn ein Fehler auftritt
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kamera')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final image = await _controller.takePicture();

            // Speichere das Bild temporär
            final directory = await getApplicationDocumentsDirectory();
            final imagePath = '${directory.path}/${DateTime.now()}.png';
            final imageFile = await File(image.path).copy(imagePath);

            // Lade das Bild hoch und erhalte die URL
            final imageUrl = await _uploadAndSendImage(imageFile);
            if (imageUrl != null) {
              // Gebe die Bild-URL an den Chat zurück
              Navigator.pop(context, imageUrl);
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Fehler beim Aufnehmen: $e')),
            );
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}