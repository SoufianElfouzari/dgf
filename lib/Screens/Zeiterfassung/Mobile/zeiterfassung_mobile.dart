import 'package:baustellenapp/Constants/colors.dart';
import 'package:baustellenapp/Screens/Baustellenoverview/Mobile/baustellen_overview.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:baustellenapp/DataBase/appwrite_constant.dart';

class AppwriteService {
  final Client client;
  final Databases databases;

  AppwriteService(this.client) : databases = Databases(client);

  // Fetch all users from the user collection
  Future<List<Document>> fetchAllUsers() async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.usercollectionId,
      );
      return response.documents; // List of all user documents
    } catch (e) {
      return [];
    }
  }

  // Fetch a user document based on login credentials
  Future<Document?> fetchUserByLogin(String email, String password) async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.usercollectionId,
        queries: [
          Query.equal('email', email),
          Query.equal('password', password),
        ],
      );
      if (response.documents.isNotEmpty) {
        return response.documents.first;
      }
    } catch (e) {
    }
    return null;
  }
}

class Zeiterfassung extends StatefulWidget {
  Document? currentUserDocument;
  final Client client;
  final String userId;

  Zeiterfassung({super.key, required this.client, required this.currentUserDocument, required this.userId});

  @override
  _ZeiterfassungState createState() => _ZeiterfassungState();
}

class _ZeiterfassungState extends State<Zeiterfassung> {
  List<Document> allUsers = [];
  bool Admin = false;
  bool isWorking = false;
  bool isPaused = false;
  Stopwatch workStopwatch = Stopwatch();
  Stopwatch pauseStopwatch = Stopwatch();
  Timer? timer;
  String workElapsedTime = "00:00:00";  // Dies kannst du beibehalten für die Anzeige
  String pauseElapsedTime = "00:00:00"; // Ebenso für Pause
  String now = DateFormat("yyyy-MM-dd").format(DateTime.now());
  late final Realtime realtime;
  RealtimeSubscription? _realtimeSubscription;
  final databases = Databases(client);

  @override
  void initState() {
    super.initState();
    realtime = Realtime(widget.client);
    _initialize();
  }

  Future<void> _saveWorkTime() async {
    try {
      // Berechne die Dauer in Sekunden (oder Minuten, je nach Wunsch)
      int workDurationInMinutes = workStopwatch.elapsed.inMinutes;
      int pauseDurationInMinutes = pauseStopwatch.elapsed.inMinutes;

      await databases.createDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.arbeitszeitCollectionID,
        documentId: 'unique()',
        data: {
          'ArbeitDauer': workDurationInMinutes,  // ArbeitDauer als Integer (Sekunden)
          'PauseDauer': pauseDurationInMinutes,  // PauseDauer als Integer (Sekunden)
          'Datum': now,
          'UserID' : widget.userId
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving work times: $e')),
      );
    }
  }


  Future<void> _initialize() async {
    await _checkAdminRole();
    _subscribeToUserUpdates(); // Subscription einrichten
    timer = Timer.periodic(const Duration(seconds: 1), _updateTime);
  }
void _subscribeToUserUpdates() {
  try {
    _realtimeSubscription = realtime.subscribe([
      'databases.${AppwriteConstants.dbId}.collections.${AppwriteConstants.usercollectionId}.documents'
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
  final String documentId = eventData['\$id'];

  if (eventType.contains('update')) {
    for (int i = 0; i < allUsers.length; i++) {
      if (allUsers[i].$id == documentId) {
        allUsers[i] = Document.fromMap(eventData);
        break;
      }
    }
    setState(() {});
  } else if (eventType.contains('create')) {
    allUsers.add(Document.fromMap(eventData));
    setState(() {});
  } else if (eventType.contains('delete')) {
    allUsers.removeWhere((doc) => doc.$id == documentId);
    setState(() {});
  }
}



  Future<void> _loadAllUserDocuments() async {
    try {
      AppwriteService appwriteService = AppwriteService(widget.client);
      List<Document> fetchedUsers = await appwriteService.fetchAllUsers();

      for (var user in fetchedUsers) {
      }

      if (fetchedUsers.isNotEmpty) {
        setState(() {
          allUsers = fetchedUsers; // UI aktualisieren
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Benutzer gefunden.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden aller Benutzer: $e')),
      );
    }
  }

  Future<void> _checkAdminRole() async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.usercollectionId,
      );


      for (var doc in response.documents) {
        if (doc.data["UserID"] == widget.currentUserDocument?.data["UserID"]) {
          Admin = doc.data['Admin'];
          break;
        }
      }
    } catch (e) {
    }

    _loginAndLoadUser();
  }

  void _loginAndLoadUser() async {
    if (Admin == true) {
      _loadAllUserDocuments();
    } else {
    }
  }

  void _startWork() {
    setState(() {
      isWorking = true;
      isPaused = false;
      workStopwatch.start();
    });

    _updateUserStatus(true); // Update the user’s status to 'Working'
  }

Future<void> _updateUserStatus(bool status) async {
  try {
    await databases.updateDocument(
      databaseId: AppwriteConstants.dbId,
      collectionId: AppwriteConstants.usercollectionId,
      documentId: widget.currentUserDocument!.$id,
      data: {
        'Worker': status,
      },
      permissions: [
        Permission.read(Role.any()),
        Permission.update(Role.any()),
      ],
    );
    setState(() {
      widget.currentUserDocument!.data['Worker'] = status;
    });
  } catch (e) {
  }
}


  void _endWork() {
    setState(() {
      isWorking = false;
      isPaused = false;
      workStopwatch.stop();
      pauseStopwatch.stop();
    });

    _saveWorkTime();
    _updateUserStatus(false); // Update the user’s status to 'Not Working'

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Work ended and times saved: $workElapsedTime')),
    );

    // Reset timers
    workStopwatch.reset();
    pauseStopwatch.reset();
    setState(() {
      pauseElapsedTime = "00:00:00";
      workElapsedTime = "00:00:00";
    });
  }

  void _pauseWork() {
    setState(() {
      isPaused = true;
      workStopwatch.stop();
      pauseStopwatch.start();
    });
  }

  void _resumeWork() {
    setState(() {
      isPaused = false;
      workStopwatch.start();
      pauseStopwatch.stop();
    });
  }


  void _updateTime(Timer timer) {
    if (workStopwatch.isRunning) {
      setState(() {
        workElapsedTime = _formatTime(workStopwatch.elapsed);
      });
    }
    if (pauseStopwatch.isRunning || isPaused) {
      setState(() {
        pauseElapsedTime = _formatTime(pauseStopwatch.elapsed);
      });
    }
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    // Dispose of the real-time subscription
    _realtimeSubscription?.close(); // Clean up real-time subscription
    // Dispose of the timer
    timer?.cancel(); // Clean up the timer
    super.dispose(); // Call the superclass's dispose method
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                "Mitarbeiterzuweisung",
                style: const TextStyle(color: AppColors.mainColor,fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              if (Admin)...[
                Column(
                  children: allUsers.map((userDoc) {
                    return ListTile(
                      leading: const Icon(Icons.work_rounded, color: AppColors.spezialColor,),
                      title: Text(userDoc.data['Name'] ?? 'Unbekannter Nutzer', style: TextStyle(color: AppColors.secondColor),),
                      trailing: Text(userDoc.data['Worker'] ? 'Ist auf der Arbeit' : 'Ist nicht auf der Arbeit', style: TextStyle(color: AppColors.secondColor),),
                    );
                  }).toList(),
                ),
              ] else ...[
                const Text('Keine Benutzer gefunden.')
              ],
              if (widget.currentUserDocument != null)
                Column(
                  children: [
                    Divider(),
                    ListTile(
                      leading: const Icon(Icons.work_rounded, color: AppColors.spezialColor,),
                      title: Text(widget.currentUserDocument!.data['Name'] ?? 'Unbekannter Nutzer', style: TextStyle(color: AppColors.secondColor),),
                      trailing: Text(isWorking ? 'Ist auf der Arbeit' : 'Ist nicht auf der Arbeit', style: TextStyle(color: AppColors.secondColor),),
                    ),
                    Divider(),
                  ],
                )
              else
                const Text('Laden...'),
              const SizedBox(height: 20),
              Text(
                'Arbeitszeit: $workElapsedTime',
                style: const TextStyle(fontSize: 24, color: AppColors.mainColor),
              ),
              const SizedBox(height: 10),
              Text(
                'Pausezeit: $pauseElapsedTime',
                style: const TextStyle(fontSize: 24, color: AppColors.mainColor),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isWorking ? _endWork : _startWork,
                child: Text(isWorking ? 'Arbeit beenden und speichern' : 'Arbeit beginnen', style: TextStyle(color: AppColors.mainColor)),
              ),
              const SizedBox(height: 10),
              if (isWorking)
                ElevatedButton(
                  onPressed: isPaused ? _resumeWork : _pauseWork,
                  child: Text(isPaused ? 'Pause beenden und Arbeit fortsetzen' : 'Pause', style: TextStyle(color: AppColors.mainColor)),
                ),
            ]
          ),
        ),
      ),
    );
  }
}