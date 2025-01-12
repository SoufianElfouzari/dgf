// ignore_for_file: avoid_print, non_constant_identifier_names

import 'package:baustellenapp/Constants/colors.dart';
import 'package:baustellenapp/DataBase/appwrite_constant.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';

class ProjectDetail extends StatefulWidget {
  final String projectName;
  final String projectAdress;
  final String? projectLeader;
  final String currentBaustelleId;
  final String userID;

  const ProjectDetail({
    super.key,
    required this.projectName,
    required this.projectAdress,
    this.projectLeader,
    required this.currentBaustelleId,
    required this.userID
  });

  @override
  // ignore: library_private_types_in_public_api
  _ProjectDetailState createState() => _ProjectDetailState();
}

class _ProjectDetailState extends State<ProjectDetail> {
  late Client client;
  late Account account;
  late Databases databases;
  List<Document> userList = [];
  List<Document> comments = [];
  String newComment = '';
  List<String> assignedWorkers = [];
  bool admin = false;

  @override
  void initState() {
    super.initState();
    _initializeAppwrite();
    _fetchData();
    _checkAssignedWorkers();
  }

  void _initializeAppwrite() {
    client = Client()
      ..setEndpoint(AppwriteConstants.endPoint)
      ..setProject(AppwriteConstants.projectId);

    account = Account(client);
    databases = Databases(client);
  }

  Future<void> _fetchData() async {
    await _checkAdminRole();
    await _fetchUsers();
    await _fetchComments();
    await _checkAssignedWorkers();
  }

  Future<void> _fetchUsers() async {
    try {
      var response = await databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.usercollectionId,
      );

      setState(() {
        userList = response.documents;
      });
    } catch (e) {
      // ignore: duplicate_ignore
      // ignore: avoid_print
      print('Error fetching users: $e');
    }
  }

  Future<void> _fetchComments() async {
    try {
      var response = await databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.benutzer1CollectionID,
      );

      setState(() {
        comments = response.documents
            .where((doc) => doc.data['baustelleId'] == widget.currentBaustelleId)
            .toList();
      });
    } catch (e) {
      print('Error fetching comments: $e');
    }
  }

  Future<void> _checkAdminRole() async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.usercollectionId,
      );

      for (var doc in response.documents) {
        if (doc.$id == widget.userID) {
          admin = doc.data['Admin'];
          break;
        }
      }
    } catch (e) {
      print('Error fetching admin roles: $e');
    }
  }

  Future<void> _checkAssignedWorkers() async {
    setState(() {
      assignedWorkers.clear(); // Clear the list before checking
      for (var assignedCurrentWorker in userList) {
        print("Yea");
        if (assignedCurrentWorker.data["AssignedTo"] == widget.currentBaustelleId) {
          print("Yea2");
          assignedWorkers.add(assignedCurrentWorker.data["Name"]);
          print("Yea3");
        }
        print("Yea4");
      }
    });
  }

  Future<void> _addComment(String commentText) async {
    if (commentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment cannot be empty.')),
      );
      return;
    }

    try {
      await databases.createDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.benutzer1CollectionID,
        documentId: 'unique()', // Unique ID for the document
        data: {
          'text': commentText,
          'baustelleId': widget.currentBaustelleId,
        },
      );

      _fetchComments(); // Refresh comments after adding
      setState(() {
        newComment = ''; // Clear the input field
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment saved: $commentText')),
      );
    } catch (e) {
      print('Error adding comment: $e');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save comment: $e')),
      );
    }
  }

  Future<void> _editComment(String documentId, String commentText) async {
    if (commentText.isEmpty) return;

    try {
      await databases.updateDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.benutzer1CollectionID,
        documentId: documentId,
        data: {
          'text': commentText,
        },
      );

      _fetchComments(); // Refresh comments after editing
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment updated: $commentText')),
      );
    } catch (e) {
      print('Error editing comment: $e');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update comment: $e')),
      );
    }
  }

  Future<void> _deleteComment(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.benutzer1CollectionID,
        documentId: documentId,
      );

      _fetchComments(); // Refresh comments after deleting
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted')),
      );
    } catch (e) {
      print('Error deleting comment: $e');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete comment: $e')),
      );
    }
  }

  Future<void> _deleteProjekt(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.baustellenoverviewCollectionId,
        documentId: documentId,
      );

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projekt deleted')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error deleting comment: $e');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.mainColor,
        title: Text(widget.projectName, style: const TextStyle(color: AppColors.thirdColor),),
        actions: [
          IconButton(
            onPressed: () {
              deleteProjekt(screenWidth);
            }, 
            icon: const Icon(Icons.delete)
          ),
          IconButton(
            onPressed: () {}, 
            icon: const Icon(Icons.document_scanner)
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.blue, size: 30),
                const SizedBox(width: 10),
                Text('Projektleiter: ${widget.projectLeader ?? 'Keiner Zugewiesen'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mainColor)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 30),
                const SizedBox(width: 10),
                Text('Adresse: ${widget.projectAdress}', style: const TextStyle(fontSize: 18, color: AppColors.mainColor)),
              ],
            ),
            const SizedBox(height: 20),

            // Worker selection for admins
            if (admin) ...[
              const Text('Wähle Arbeiter:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mainColor)),
              MultiSelectDialogField(
  backgroundColor: AppColors.spezialColor,
  items: userList.map((user) {
    return MultiSelectItem<Document>(
      user, 
      user.data['Name'], // Gebe den Namen als String an
    );
  }).toList(),
  title: const Text(
    "Wähle Arbeiter", 
    style: TextStyle(color: AppColors.thirdColor), // Farbe des Titels im Dialog
  ),
  selectedColor: AppColors.mainColor, // Die Farbe der ausgewählten Items
  buttonText: const Text(
    "Arbeiter Hinzufügen",
    style: TextStyle(color: AppColors.spezialColor, fontSize: 16), // Farbe des Button-Textes
  ),
  onConfirm: (List<Document> selectedWorkers) async {
    setState(() {
      assignedWorkers = selectedWorkers.map((worker) => worker.data['Name'] as String).toList();
    });

    _checkAssignedWorkers();

    // Get the list of worker IDs to save in the project
    selectedWorkers.map((worker) => worker.$id).toList();

    // Save the assignment in Appwrite for workers and update the project
    for (var User in selectedWorkers) {
      String UserId = User.$id;
      await _updateWorkerAssignment(UserId); // Assign worker
    }

    // Update the project (Baustelle) with the list of assigned workers

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        'Zugewiesene Arbeiter: ${assignedWorkers.join(', ')}',
        style: const TextStyle(color: AppColors.mainColor), // Textfarbe für die Snackbar
      )),
    );
  },
)
] else ...[
              const SizedBox(height: 10),
              const Text(
                'You do not have permission to select workers.',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ],

            const SizedBox(height: 20),

            // Display the list of assigned workers
            if (assignedWorkers.isNotEmpty) ...[
              const Text('Zugewiesene Arbeiter:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mainColor)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: assignedWorkers.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.person, color: AppColors.inactiveIconColor,),
                    title: Text(assignedWorkers[index], style: const TextStyle(color: AppColors.spezialColor)),
                  );
                },
              ),
            ] else
              const Text('No workers assigned.'),

            const SizedBox(height: 20),

            // Comment section for admins
            const Text('Kommentar Hinzufügen:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mainColor)),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Geben sie ihre Kommentare hier ein',
              ),
              onChanged: (value) {
                setState(() {
                  newComment = value; // Store the entered comment
                });
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
  onPressed: () {
    _addComment(newComment); // Speichert den Kommentar in Appwrite
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.mainColor, // Hintergrundfarbe des Buttons
  ),
  child: const Text(
    'Kommentar Speichern',
    style: TextStyle(color: AppColors.secondColor), // Textfarbe
  ),
),

            const SizedBox(height: 20),

            // Display comments
            const Text('Comments:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mainColor)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                return ListTile(
                  title: Text(comment.data['text']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _showEditDialog(comment.$id); // Open dialog to edit comment
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteComment(comment.$id); // Delete comment
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

Future<void> _updateWorkerAssignment(String UserId) async {
  try {
    await databases.updateDocument(
  databaseId: AppwriteConstants.dbId,
  collectionId: AppwriteConstants.usercollectionId,
  documentId: UserId,
  data: {
    'Assigned': true, // Boolean statt String
    'AssignedTo': widget.currentBaustelleId, // Als String speichern
  },
);

    print('Worker $UserId updated successfully.');
  } catch (e) {
    print('Error updating worker $UserId: $e');
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to assign worker: $e')),
    );
  }
}

  void _showEditDialog(String documentId) {
    String commentText = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Comment'),
          content: TextField(
            onChanged: (value) {
              commentText = value; // Store the new comment text
            },
            decoration: const InputDecoration(hintText: "Enter new comment"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _editComment(documentId, commentText); // Update the comment
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without saving
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void deleteProjekt(double screenWidth) {
  showDialog(
    context: context,
    barrierDismissible: true, // Allows closing the dialog by tapping outside
    builder: (context) {
      return Dialog(
        backgroundColor: AppColors.spezialColor,
        insetPadding: EdgeInsets.only(
          left: screenWidth / 5,
          right: screenWidth / 5,
          top: screenWidth / 1.3,
          bottom: screenWidth / 1.3,
        ), // Adjust the padding for better appearance
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Bist du sicher, dass du Projekt ${widget.projectName} löschen willst?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: screenWidth / 28.5),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () {
                      _deleteProjekt(widget.currentBaustelleId); // Pass the project ID
                      Navigator.of(context).pop(); // Close the dialog
                    },
                    child: Container(
                      width: screenWidth / 6.5,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(screenWidth / 80),
                        color: Colors.red.withOpacity(0.5),
                      ),
                      child: Center(
                        child: Text(
                          "Löschen",
                          style: TextStyle(color: AppColors.secondColor),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(); // Close the dialog without doing anything
                    },
                    child: Container(
                      width: screenWidth / 6.5,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(screenWidth / 80),
                        color: AppColors.backgroundColor.withOpacity(0.5),
                      ),
                      child: Center(
                        child: Text(
                          "Abbrechen",
                          style: TextStyle(color: AppColors.secondColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}




}