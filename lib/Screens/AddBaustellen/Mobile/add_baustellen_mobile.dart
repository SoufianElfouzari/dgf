// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:io';
import 'package:baustellenapp/Constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appwrite/appwrite.dart';
import 'package:baustellenapp/DataBase/appwrite_constant.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

class AddBaustelleScreen extends StatefulWidget {
  final Client client;
  final String userId;

  const AddBaustelleScreen({super.key, required this.client, required this.userId});

  @override
  State<AddBaustelleScreen> createState() => _AddBaustelleScreenState();
}

class _AddBaustelleScreenState extends State<AddBaustelleScreen> {
  final _formKey = GlobalKey<FormState>();
  late Databases databases;
  late Storage storage;

  String name = '';
  String address = '';
  String projectLeader = '';
  String assigned = '';
  String description = '';
  File? selectedImage; // For mobile/desktop platforms
  Uint8List? webImageBytes; // For storing image bytes on the web
  String imageId = '';

  @override
  void initState() {
    super.initState();
    databases = Databases(widget.client);
    storage = Storage(widget.client);
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        print('Picked image path: ${pickedFile.path}');

        if (kIsWeb) {
          // For web, read bytes
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            webImageBytes = bytes; // Store the image bytes for web
          });
        } else {
          // For mobile, use File
          setState(() {
            selectedImage = File(pickedFile.path);
          });
        }
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> uploadImage() async {
    if (selectedImage == null && webImageBytes == null) return;

    try {
      InputFile file;
      if (kIsWeb) {
        // Create InputFile from bytes for web
        file = InputFile.fromBytes(
          bytes: webImageBytes!,
          filename: 'web_image.png',
        );
      } else {
        // Create InputFile from path for mobile
        // ignore: deprecated_member_use
        file = InputFile(path: selectedImage!.path);
      }

      final result = await storage.createFile(
        bucketId: AppwriteConstants.storageBucketId,
        fileId: 'unique()',
        file: file,
      );

      setState(() {
        imageId = result.$id;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Hochladen des Bildes: $e')),
      );
    }
  }

 Future<void> addBaustelle() async {
  if (_formKey.currentState?.validate() ?? false) {
    _formKey.currentState?.save();
    await uploadImage();

    try {
      await databases.createDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.baustellenoverviewCollectionId,
        documentId: 'unique()',
        data: {
          'Name': name,
          'Adress': address,
          'Projektleiter': projectLeader,
          'Assigned': assigned,
          'Beschreibung': description,
          'ImageID': imageId,
          'UserId': widget.userId,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Baustelle erfolgreich hinzugefügt!')),
      );

      Navigator.pop(context, true); // Rückgabewert: true signalisiert Erfolg
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Hinzufügen: $e')),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(backgroundColor: AppColors.mainColor, title: const Text('Neue Baustelle hinzufügen', style: TextStyle(color: AppColors.thirdColor),)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2.5),
                      color: AppColors.spezialColor,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Name erforderlich' : null,
                        onSaved: (value) => name = value ?? '',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2.5),
                      color: AppColors.spezialColor,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Adresse'),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Adresse erforderlich' : null,
                        onSaved: (value) => address = value ?? '',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2.5),
                      color: AppColors.spezialColor,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Projektleiter'),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Projektleiter erforderlich' : null,
                        onSaved: (value) => projectLeader = value ?? '',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2.5),
                      color: AppColors.spezialColor,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Beschreibung'),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Beschreibung erforderlich' : null,
                        onSaved: (value) => description = value ?? '',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Image display logic for web and mobile
                webImageBytes != null || selectedImage != null
                    ? kIsWeb
                        ? Image.memory(
                            webImageBytes!,
                            height: 150,
                          )
                        : Image.file(
                            selectedImage!,
                            height: 150,
                          )
                    : const Text('Kein Bild ausgewählt', style: TextStyle(color: AppColors.inactiveIconColor),),
                TextButton(
                  onPressed: pickImage,
                  child: const Text('Bild auswählen', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline, decorationColor: Colors.blueAccent) ,),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor, // Background color
                      foregroundColor: AppColors.secondColor, // Text color
                  ),
                  onPressed: addBaustelle,
                  child: const Text('Baustelle hinzufügen', style: TextStyle(color: AppColors.spezialColor)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
