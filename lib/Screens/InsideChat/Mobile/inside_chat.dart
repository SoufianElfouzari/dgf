

import 'package:baustellenapp/Constants/colors.dart';
import 'package:baustellenapp/Screens/ContactProfile/Mobile/contact_profile.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:baustellenapp/DataBase/appwrite_constant.dart'; // Ensure this contains your AppwriteConstants
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart'; // Optional for caching

class InsideChat extends StatefulWidget {
  final Client client;
  final String userID; 
  final String receiverID; 
  final String receiverName; 
  final String userName; 
  const InsideChat({
    super.key, 
    required this.client,
    required this.userID, 
    required this.receiverID, 
    required this.receiverName,  
    required this.userName, 
  });

  @override
  State<InsideChat> createState() => _ChatState();
}

class _ChatState extends State<InsideChat> {
  List<Map<String, dynamic>> chat = []; // List for chat messages with sender ID
  TextEditingController controller = TextEditingController(); // Controller for the text field
  late Databases databases; // Declare the database
  late final Realtime realtime;
  RealtimeSubscription? _realtimeSubscription;
  final ScrollController _scrollController = ScrollController(); // ScrollController for auto-scrolling

  @override
  void initState() {
    super.initState();
    databases = Databases(widget.client);
    realtime = Realtime(widget.client); // Initialize Realtime
    _subscribeToUserUpdates();
    _loadChat(); // Load chat and mark messages as read
  }

  Future<void> _loadChat() async {
    await fetchMessages();
    await markMessagesAsRead();
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Important: Release the controller
    _realtimeSubscription?.close(); // Close the real-time subscription
    super.dispose();
  }

  Future<void> fetchMessages() async {
  try {
    // Query for messages from user to receiver
    final response1 = await databases.listDocuments(
      databaseId: AppwriteConstants.dbId,
      collectionId: AppwriteConstants.messagecollectionID,
      queries: [
        Query.equal('SenderID', widget.userID),
        Query.equal('RecieverID', widget.receiverID), // Keep the spelling as in the database
        Query.orderDesc('Datum'), // Sort by newest first
        Query.limit(100), // Adjust the limit accordingly
      ],
    );

    // Query for messages from receiver to user
    final response2 = await databases.listDocuments(
      databaseId: AppwriteConstants.dbId,
      collectionId: AppwriteConstants.messagecollectionID,
      queries: [
        Query.equal('SenderID', widget.receiverID),
        Query.equal('RecieverID', widget.userID), // Keep the spelling as in the database
        Query.orderDesc('Datum'), // Sort by newest first
        Query.limit(100), // Adjust the limit accordingly
      ],
    );

    List<Map<String, dynamic>> fetchedChat = [];

    // Add messages from both queries
    for (var doc in [...response1.documents, ...response2.documents]) {
      bool isImage = doc.data['Image'] ?? false;
      bool isTodo = doc.data['isTodo'] ?? false; // To-Do-Flag
      String messageText = isImage 
          ? doc.data['ImageID'] ?? '' 
          : isTodo 
              ? doc.data['TodoText'] ?? 'Unbekanntes To-Do' 
              : doc.data['Text'] ?? 'Unbekannte Nachricht';
      String senderID = doc.data['SenderID'] ?? 'No Sender';
      String receiverID = doc.data['RecieverID'] ?? 'No Receiver'; // Keep the spelling as in the database

      fetchedChat.add({
  'text': messageText,
  'userID': senderID,
  'recieverID': receiverID,
  'id': doc.$id,
  'Datum': doc.data['Datum'] ?? '',
  'Image': isImage,
  'ImageID': doc.data['ImageID'] ?? '',
  'isTodo': isTodo,
  // Hier KEIN ?? false verwenden, damit null-Wert möglich ist
  'TodoStatus': doc.data.containsKey('TodoStatus') ? doc.data['TodoStatus'] : null,
});}

    // Sort the combined messages by date
    fetchedChat.sort((a, b) {
      DateTime dateA = DateTime.tryParse(a['Datum']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      DateTime dateB = DateTime.tryParse(b['Datum']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateA.compareTo(dateB);
    });

    setState(() {
      chat = fetchedChat;
    });

    // Optional: Scroll to the newest message after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && chat.isNotEmpty) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

  } catch (e) {
  }
}

  Future<void> markMessagesAsRead() async {
    try {
      // Query for unread messages from the receiver
      final response = await databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.messagecollectionID,
        queries: [
          Query.equal('SenderID', widget.receiverID),
          Query.equal('RecieverID', widget.userID),
          Query.equal('isRead', false),
        ],
      );

      // Update each unread message to set 'isRead' to true
      for (var doc in response.documents) {
        await databases.updateDocument(
          databaseId: AppwriteConstants.dbId,
          collectionId: AppwriteConstants.messagecollectionID,
          documentId: doc.$id,
          data: {'isRead': true},
        );
      }

    } catch (e) {
    }
  }

  void sendMessage() {
    if (controller.text.isNotEmpty) {
      _addComment(controller.text);
      controller.clear(); // Clear the text field
    }
  }

  void _subscribeToUserUpdates() {
    try {
      _realtimeSubscription = realtime.subscribe([
        'databases.${AppwriteConstants.dbId}.collections.${AppwriteConstants.messagecollectionID}.documents'
      ]);

      _realtimeSubscription!.stream.listen((event) {
        if (mounted) {
          _processRealtimeEvent(event);
        }
      }, onError: (error) {
      });
    } catch (e) {
    }
  }

  void _processRealtimeEvent(RealtimeMessage event) {
  final Map<String, dynamic> eventData = event.payload;
  final String eventType = event.events.first;

  String senderID = eventData['SenderID'] ?? '';
  String receiverID = eventData['RecieverID'] ?? '';

  if ((senderID == widget.userID && receiverID == widget.receiverID) ||
      (senderID == widget.receiverID && receiverID == widget.userID)) {
    if (eventType.contains('create')) {
      bool isImage = eventData['Image'] ?? false;
      bool isTodo = eventData['isTodo'] ?? false;
      String messageText = isImage 
          ? eventData['ImageID'] ?? '' 
          : isTodo 
              ? eventData['TodoText'] ?? 'Unbekanntes To-Do' 
              : eventData['Text'] ?? 'Unbekannte Nachricht';

      setState(() {
        chat.add({
          'text': messageText,
          'userID': senderID,
          'recieverID': receiverID,
          'id': eventData['\$id'],
          'Datum': eventData['Datum'] ?? '',
          'Image': isImage,
          'ImageID': eventData['ImageID'] ?? '',
          'isTodo': isTodo,
          'TodoStatus': eventData['TodoStatus'] ?? false,
        });
      });

      // ... bestehender Code zum Scrollen ...
    } else if (eventType.contains('update')) {
      // Optional: Handle updates if necessary
    } else if (eventType.contains('delete')) {
      setState(() {
        chat.removeWhere((msg) => msg['id'] == eventData['\$id']);
      });
    }
  }
}

  Future<void> _addComment(String messageText) async {
    if (messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nachricht darf nicht leer sein.')),
      );
      return;
    }

    try {
      await databases.createDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.messagecollectionID,
        documentId: 'unique()', // Unique ID for the document
        data: {
          'Text': messageText,
          'SenderID': widget.userID,
          'RecieverID': widget.receiverID, // Keep the spelling as in the database
          'Image': false,
          'Datum': DateTime.now().toIso8601String(), // Date as ISO8601 string
          'ImageID': null,
          'isRead': false, // Initialize as unread
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nachricht konnte nicht gespeichert werden: $e')),
      );
    }
  }

  // Function to open the image source selection
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bildquelle auswählen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () async {
                  Navigator.of(context).pop(); // Close the dialog
                  final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
                  if (pickedFile != null) {
                    final bytes = await pickedFile.readAsBytes();
                    await _uploadImage(bytes); // Upload the image
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Datei auswählen'),
                onTap: () async {
                  Navigator.of(context).pop(); // Close the dialog
                  final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    final bytes = await pickedFile.readAsBytes();
                    await _uploadImage(bytes); // Upload the image
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadImage(Uint8List imageBytes) async {
    try {
      Storage storage = Storage(widget.client);

      // Create the file first to get the ID
      final result = await storage.createFile(
        bucketId: AppwriteConstants.storageBucketId,
        fileId: 'unique()', // Generate a unique file ID
        file: InputFile(
          bytes: imageBytes,
          filename: 'chat_image_${DateTime.now().millisecondsSinceEpoch}.png', // Unique filename
        ),
      );

      // Save image message in the database
      await databases.createDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.messagecollectionID,
        documentId: 'unique()', // Unique ID for the document
        data: {
          'Image': true,
          'ImageID': result.$id,
          'SenderID': widget.userID,
          'RecieverID': widget.receiverID, // Keep the spelling as in the database
          'Datum': DateTime.now().toIso8601String(), // Date as ISO8601 string
          'isRead': false, // Initialize as unread
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Hochladen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ContactProfile(userId: widget.userID)));
          },
          child: Text(
            widget.receiverName, 
            style: const TextStyle(
              fontWeight: FontWeight.bold, 
              color: AppColors.secondColor
            )
          )
        ),
        backgroundColor: AppColors.mainColor,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop(); // Go back to the previous screen
          },
          icon: const Icon(Icons.arrow_back, size: 30, color: AppColors.secondColor),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.video_call, size: 30, color: AppColors.secondColor),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.call, size: 30, color: AppColors.secondColor),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
  child: ListView.builder(
              controller: _scrollController, // Added
              reverse: false, // Display messages from top to bottom
              itemCount: chat.length,
              itemBuilder: (context, index) {
                final message = chat[index];
            bool isSender = message["userID"] == widget.userID; // Check if the message is from the current user
              bool isImage = message["Image"] == true; // Check if it's an image message

              // Prüfen, ob die Nachricht eine To-Do ist
              if (message['isTodo'] == true) {
                return _buildTodoWidget(message, isSender);}
              

                return Padding(
  padding: const EdgeInsets.all(8.0),
  child: Align(
    alignment: isSender ? Alignment.centerRight : Alignment.centerLeft, // Right for sender, left for receiver
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: isSender ? AppColors.spezialColor : Colors.deepOrange.shade100, // Different colors for sender and receiver
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: isImage
          ? (() {
              // Print the image URL here
              print('Bild-URL: https://cloud.appwrite.io/v1/storage/buckets/${AppwriteConstants.storageBucketId}/files/${message["ImageID"]}/view?project=${AppwriteConstants.projectId}&mode=admin');
              return GestureDetector(
                onTap: () {
                   _showFullScreenImage(message["ImageID"]); // Bild anzeigen im Popup

                },
                child: SizedBox(
                  width: 200,
                  height: 250,
                  child: Image.network(
                    "https://cloud.appwrite.io/v1/storage/buckets/${AppwriteConstants.storageBucketId}/files/${message["ImageID"]}/view?project=${AppwriteConstants.projectId}&mode=admin",
                    fit: BoxFit.cover,
                    )
                  ),
              );
            })() // Show the image if it's an image message
          : Text(
              message["text"],
              style: const TextStyle(
                color: Colors.black, // Change to black for better readability
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
    ),
  ),
);
},
            ),
),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              color: AppColors.secondColor,
              boxShadow: [
                BoxShadow(
                  color: AppColors.inactiveIconColor.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 7,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _showImageSourceDialog, // Open the image source selection
                  icon: const Icon(Icons.camera_alt, color: AppColors.mainColor, size: 28),
                ),
                IconButton(
                  onPressed: () {}, // Function for voice recording (can be adjusted)
                  icon: const Icon(Icons.mic, color: AppColors.mainColor, size: 28),
                ),
                Expanded(
                  child: Container(
                    height: 45,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                    ),
                    child: TextField(
                      controller: controller,
                      onChanged: (text) {
                        setState(() {}); // Update the state when the text changes
                      },
                      decoration: const InputDecoration(
                        hintText: "Nachricht schreiben...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                // Show send button only when the text field is not empty
                if (controller.text.isNotEmpty) 
                  IconButton(
                    onPressed: sendMessage,
                    icon: const Icon(Icons.send, color: AppColors.mainColor, size: 28),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 // Im Widget:
Widget _buildTodoWidget(Map<String, dynamic> message, bool isSender) {
  bool? todoStatus = message["TodoStatus"]; // Kann true, false oder null sein

  // Wenn noch keine Entscheidung (null), zeige Buttons, falls Empfänger
  if (!isSender && todoStatus == null) {
    print("TODOYES");
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Container(
        width: 350,
        decoration: const BoxDecoration(
          color: AppColors.inactiveIconColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${message["text"]}\nSender: ${widget.receiverName}",
                style: TextStyle(
                  color: AppColors.thirdColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _acceptTodo(message['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text("Annehmen"),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _rejectTodo(message['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text("Ablehnen"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  } else if (todoStatus == true) {
    // Angenommen
    return _buildStatusText("${message["text"]}", Colors.green, true, true, isSender);
  } else if (todoStatus == false) {
    // Abgelehnt
    return _buildStatusText("${message["text"]}", Colors.red, false, true, isSender);
  } else {
    // Falls aus irgendeinem Grund ein anderer Zustand kommt (sollte nicht passieren),
    // zeigen wir nur den Text an, ohne Buttons.
    return _buildStatusText("${message["text"]}", AppColors.thirdColor, false, false, isSender);
  }
}

Widget _buildStatusText(String text, Color color, bool status, bool seen, bool isSender) {
  double screenWidth = MediaQuery.of(context).size.width;
  return Padding(
    padding: const EdgeInsets.all(8),
    child: Container(
      decoration: BoxDecoration(
        color: isSender ? AppColors.spezialColor : Colors.deepOrange.shade100,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),]
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            Text(
              "${text}\nSender: ${isSender ? widget.userName : widget.receiverName}",
              style: TextStyle(
                color: color,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Spacer(),

            Text(
              seen ? status ? "ToDo wurde\nAngenommen" : "ToDo wurde\nAbgelehnt" : "ToDo wurde\nnoch nicht beantwortet",
              style: TextStyle(
                fontSize: screenWidth/30,
                color: color
              ),
              textAlign: TextAlign.center,
            ),
            Spacer(),
          ],
        ),
      ),
    ),
  );
}
// Die Methode _rejectTodo muss hier hinzugefügt werden
  Future<void> _rejectTodo(String documentId) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.messagecollectionID,
        documentId: documentId,
        data: {
          'TodoStatus': false, // Setze den Status auf abgelehnt
        },
      );

      setState(() {
        // Aktualisieren Sie den lokalen Zustand, um die Änderung sofort anzuzeigen
        final index = chat.indexWhere((msg) => msg['id'] == documentId);
        if (index != -1) {
          chat[index]['TodoStatus'] = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To-Do abgelehnt!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Ablehnen des To-Dos: $e')),
      );
    }
  }


Future<void> _acceptTodo(String documentId) async {
  try {
    await databases.updateDocument(
      databaseId: AppwriteConstants.dbId,
      collectionId: AppwriteConstants.messagecollectionID,
      documentId: documentId,
      data: {
        'TodoStatus': true,
      },
    );

    setState(() {
      // Aktualisieren Sie den lokalen Zustand, um die Änderung sofort anzuzeigen
      final index = chat.indexWhere((msg) => msg['id'] == documentId);
      if (index != -1) {
        chat[index]['TodoStatus'] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('To-Do angenommen!')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fehler beim Annehmen des To-Dos: $e')),
    );
  }
}

void _showFullScreenImage(String imageId) {
  showDialog(
    context: context,
    barrierDismissible: true, // Erlaubt das Schließen durch Tippen außerhalb des Bildes
    builder: (context) {
      return Dialog(
        insetPadding: EdgeInsets.only(left: 50, right: 50, top: 150, bottom: 150), // Optional, um das Dialog-Fenster ein wenig abzurunden
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).pop(); // Schließt das Dialog-Fenster
          },
          child: Center(
            child: Image.network(
              "https://cloud.appwrite.io/v1/storage/buckets/${AppwriteConstants.storageBucketId}/files/$imageId/view?project=${AppwriteConstants.projectId}&mode=admin",
              fit: BoxFit.contain, // Bild wird im Dialog größer angezeigt
            ),
          ),
        ),
      );
    },
  );
}


}
