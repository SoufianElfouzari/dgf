import 'package:baustellenapp/Constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:baustellenapp/DataBase/appwrite_constant.dart'; // Import für Konstanten
import 'package:baustellenapp/DataBase/appwrite_service.dart'; // Import für AppwriteService

class Kalender extends StatefulWidget {
  final String userID; // Deklaration der userID als final
  bool isDataFetched;
  Map<DateTime, List<Map<String, dynamic>>> events;
  List<Map<String, dynamic>> announcements;
  List<Document> userList;
  Map<String, String> userMap;
  List<String> assignedWorkers;

  Kalender({
    super.key, 
    required this.userID, 
    required this.isDataFetched,
    required this.events,
    required this.announcements,
    required this.userList,
    required this.userMap,
    required this.assignedWorkers,
    }); // Markiert userID als erforderlich

  @override
  _KalenderState createState() => _KalenderState();
}

class _KalenderState extends State<Kalender> {
  late Client _client;
  late Databases _databases;
  late final ValueNotifier<List<Map<String, dynamic>>> _selectedEvents;
  DateTime? _selectedDay;
  bool _isCalendarVisible = true; // Variable zur Steuerung der Kalenderanzeige
  late AppwriteService _appwriteService; // AppwriteService Instanz

  @override
  void initState() {
    super.initState();
    _selectedEvents = ValueNotifier([]);
    _initializeAppwrite();  // Warten, bis Appwrite initialisiert ist
    if (!widget.isDataFetched) {
      print("\nFetched"*100);
      _initializeData();
    }
  }

Future<void> _initializeData() async {
  if (_databases != null) {
    await _fetchUsers();  // Stelle sicher, dass Benutzerdaten abgerufen werden, bevor du fortfährst
        // Rufe Aufgaben und Ankündigungen ab, nachdem _databases initialisiert wurde
    _fetchEvents(widget.userID);
    _fetchAnnouncements(); 
    _updateSelectedEvents();
    setState(() {
      widget.isDataFetched = true;  // Flag setzen, dass Daten erfolgreich abgerufen wurden
    });
  }
}

Future<void> _initializeAppwrite() async {
  _client = Client()
    ..setEndpoint(AppwriteConstants.endPoint)
    ..setProject(AppwriteConstants.projectId);
  
  _databases = Databases(_client); // _databases wird hier initialisiert
  _appwriteService = AppwriteService(); // Initialisierung von AppwriteService mit existierendem Client


}

  void _shareTodo(Map<String, dynamic> todo) async {
    // Überprüfen, ob die Benutzerliste geladen ist
    if (widget.userList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Keine Benutzer zum Teilen verfügbar.')),
      );
      return;
    }

    // Dialog zur Auswahl des Empfängers anzeigen
    String? selectedUserID = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Todo teilen mit'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.userList.length,
              itemBuilder: (context, index) {
                final user = widget.userList[index];
                if (user.$id == widget.userID) {
                  // Aktuellen Benutzer überspringen
                  return SizedBox.shrink();
                }
                return ListTile(
                  leading: user.data['avatarUrl'] != null
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(user.data['avatarUrl']),
                        )
                      : CircleAvatar(
                          child: Text(
                            user.data['Name'] != null && user.data['Name'].isNotEmpty
                                ? user.data['Name'][0]
                                : '?',
                          ),
                        ),
                  title: Text(user.data['Name'] ?? 'Unbekannt'),
                  onTap: () {
                    Navigator.of(context).pop(user.$id);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog ohne Auswahl schließen
              },
              child: Text('Abbrechen'),
            ),
          ],
        );
      },
    );

    if (selectedUserID != null) {
      // Strukturierte Todo-Details formatieren
      String todoDetails = 'Aufgabe: ${todo['text']}\n'
          'Zeit: ${todo['time']}\n'
          'Priorität: ${todo['priority']}';

      // Nachricht senden
      try {
        await _databases.createDocument(
          databaseId: AppwriteConstants.dbId,
          collectionId: AppwriteConstants.messagecollectionID,
          documentId: ID.unique(),
          data: {
            'SenderID': widget.userID,
            'RecieverID': selectedUserID,
            'TodoText': todoDetails,
            'Datum': DateTime.now().toIso8601String(),
            'isRead': false,
            'isTodo': true,
          },

        );

        // Bestätigung anzeigen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Todo erfolgreich im Chat geteilt.')),
        );
      } catch (e) {
        // Fehler in den Debug-Logs anzeigen
        print('Fehler beim Teilen der Todo: $e');
        // Optional: Fehlermeldung im UI anzeigen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Teilen der Todo.')),
        );
      }
    }
  }


void _fetchEvents(String currentUserId) async {
  widget.events.clear(); // Alte Daten vor dem Abruf löschen
  int batchSize = 200; // Anzahl der Dokumente pro Anfrage
  int page = 0; // Startseite
  bool hasMoreDocuments = true;

  try {
    while (hasMoreDocuments) {
      final response = await _databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.task,
        queries: [
          Query.limit(batchSize),
          Query.offset(page * batchSize),
        ],
      );

      print('Documents fetched: ${response.documents}');

      if (response.documents.length < batchSize) {
        hasMoreDocuments = false;
      }

      for (var doc in response.documents) {
        DateTime date = DateTime.parse(doc.data['date']);
        String text = doc.data['text'] ?? 'No Task';
        String priority = doc.data['priority'] ?? 'Normal';
        String time = doc.data['time'] ?? 'No Time';
        String creatorId = doc.data['SenderID'] ?? 'No Sender';
        String documentId = doc.$id;

        // Empfänger-IDs auslesen und überprüfen
        List<String> recieverIds = [];
        if (doc.data['RecieverID'] != null && doc.data['RecieverID'] is String) {
          recieverIds = (doc.data['RecieverID'] as String).split(',').map((id) => id.trim()).toList();
        }

        // Überprüfen, ob der aktuelle Benutzer (currentUserId) in den Empfängern enthalten ist
        if (recieverIds.contains(currentUserId)) {
          print('Task details: text=$text, priority=$priority, time=$time, creator=$creatorId, recievers=$recieverIds');

          widget.events[date] = (widget.events[date] ?? [])..add({
            'text': text,
            'priority': priority,
            'time': time,
            'creator': creatorId,
            'recievers': recieverIds,
            'documentId': documentId,
          });
        }
      }

      page++;
    }

    setState(() {
      _updateSelectedEvents(); // UI aktualisieren
    });
  } catch (e) {
    print('Error fetching tasks: $e');
  }
}

  // Ankündigungen von Appwrite abrufen
void _fetchAnnouncements() async {
  widget.announcements.clear(); // Alte Daten vor dem Abruf löschen
  int batchSize = 200; // Anzahl der Dokumente pro Anfrage
  int page = 0; // Startseite
  bool hasMoreDocuments = true;

  try {
    while (hasMoreDocuments) {
      final response = await _databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.announcement,
        queries: [
          Query.limit(batchSize),
          Query.offset(page * batchSize)
        ],
      );

      print('Documents fetched: ${response.documents.length}');

      if (response.documents.length < batchSize) {
        hasMoreDocuments = false;
      }

      for (var doc in response.documents) {
        DateTime date = DateTime.parse(doc.data['date']);
        String title = doc.data['title'] ?? 'No Title';
        String description = doc.data['description'] ?? 'No Description';
        String creator = doc.data['SenderID'] ?? 'No Sender';

        print('Announcement details: title=$title, description=$description, date=$date, creator=$creator');

        widget.announcements.add({
          'title': title,
          'description': description,
          'date': date.toIso8601String(),
          'creator': creator,
        });
      }

      page++; // Seite erhöhen, um die nächsten Dokumente abzurufen
    }

    setState(() {
      // UI aktualisieren, nachdem alle Ankündigungen geladen wurden
    });
  } catch (e) {
    print('Error fetching announcements: $e');
  }
}

  // Update ausgewählter Events basierend auf dem ausgewählten Tag
  void _updateSelectedEvents() {
    if (_selectedDay != null) {
      _selectedEvents.value = widget.events[_selectedDay] ?? [];
    }
  }

  // Ankündigungen für den ausgewählten Tag abrufen
  List<Map<String, dynamic>> _getAnnouncementsForDay(DateTime? day) {
    if (day == null) return [];
    return widget.announcements.where((announcement) {
      DateTime announcementDate = DateTime.parse(announcement['date']);
      return announcementDate.year == day.year &&
          announcementDate.month == day.month &&
          announcementDate.day == day.day;
    }).toList();
  }

  // Benutzer abrufen und userMap befüllen
  Future<void> _fetchUsers() async {
    try {
      var response = await _databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.usercollectionId, // Ersetzen Sie dies mit Ihrer Benutzer-Collection-ID
      );

      setState(() {
        widget.userList = response.documents;
        widget.userMap = {
          for (var user in widget.userList) user.$id: user.data['Name'] ?? 'Unbekannt'
        };
        print( widget.userMap);
      });
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  // Hilfsfunktion zur Abrufung des Benutzernamens anhand der userID
  String getUserName(String userId) {
    return  widget.userMap[userId] ?? 'Unbekannt';
  }

  // Hilfsfunktion zur Abrufung der Empfängernamen aus einer Liste von IDs
  String getRecieverNames(List<String> recieverIds) {
    if (recieverIds.isEmpty) return 'Keine Empfänger';
    List<String> names = recieverIds.map((id) => getUserName(id)).toList();
    return names.join(', ');
  }

  // Aufgabe zu Appwrite hinzufügen
  void _addTaskToAppwrite(Map<String, dynamic> task) async {
    try {
     
      await _databases.createDocument(
        databaseId: AppwriteConstants.dbId, // Ihre Appwrite-Datenbank-ID
        collectionId: AppwriteConstants.task, // Ihre Collection-ID
        documentId: ID.unique(), // Lassen Sie Appwrite eine eindeutige ID generieren
        data: task,
     
      );
      print('Task added successfully!');

      _fetchEvents(widget.userID); // Aktualisieren Sie die Ereignisliste nach dem Hinzufügen der Aufgabe
    } catch (e) {
      print('Error adding task: $e');
    }
  }

  // Ankündigung zu Appwrite hinzufügen
  void _addAnnouncementToAppwrite(Map<String, dynamic> announcement) async {
    try {
      await _databases.createDocument(
        databaseId: AppwriteConstants.dbId, // Ihre Appwrite-Datenbank-ID
        collectionId: AppwriteConstants.announcement, // Ihre Ankündigungs-Collection-ID
        documentId: ID.unique(), // Lassen Sie Appwrite eine eindeutige ID generieren
        data: announcement,
 
      );
      print('Announcement added successfully!');
    } catch (e) {
      print('Error adding announcement: $e');
    }
  }

  // Aufgabe aus Appwrite löschen
  void _deleteTaskFromAppwrite(String documentId) async {
    try {
      await _databases.deleteDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.task,
        documentId: documentId,
      );
      print('Task deleted successfully!');
    } catch (e) {
      print('Error deleting task: $e');
    }
  }

  // Aufgabe Dialog anzeigen (Hinzufügen/Bearbeiten)
  void _showTaskDialog({String? existingTask, String? existingPriority, String? existingTime}) {
    final TextEditingController taskController = TextEditingController(text: existingTask);
    final TextEditingController timeController = TextEditingController(text: existingTime);
    String? selectedPriority = existingPriority ?? 'Mittelschwer'; // Standard-Priorität

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Um den Zustand innerhalb des Dialogs zu verwalten
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingTask == null ? 'Neue Aufgabe hinzufügen' : 'Aufgabe bearbeiten'),
              content: SingleChildScrollView( // Um Überlauf zu handhaben
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: taskController,
                      decoration: InputDecoration(hintText: 'Aufgabentext eingeben'),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: timeController,
                      decoration: InputDecoration(hintText: 'Zeit eingeben (z.B. 14:00)'),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    SizedBox(height: 10),
                    DropdownButton<String>(
                      value: selectedPriority,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedPriority = newValue; // Priorität aktualisieren
                        });
                      },
                      items: <String>['Leicht', 'Mittelschwer', 'Schwer']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 10),
                    MultiSelectDialogField(
                      items: widget.userList.map((user) {
                        return MultiSelectItem<Document>(user, user.data['Name']);
                      }).toList(),
                      title: const Text("Leute Hinzufügen"),
                      selectedColor: AppColors.mainColor,
                      buttonText: const Text(
                        "Leute Hinzufügen",
                        style: TextStyle(color: AppColors.secondColor, fontSize: 16),
                      ),
                      onConfirm: (List<Document> selectedWorkers) {
                        setState(() {
                          // Speichern der ausgewählten Benutzer-IDs
                          widget.assignedWorkers = selectedWorkers.map((worker) => worker.$id).toList();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Assigned Workers: ${widget.assignedWorkers.join(', ')}'),
                          ));
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (taskController.text.isNotEmpty && _selectedDay != null) {
                      final newTask = {
                        'text': taskController.text,
                        'time': timeController.text,
                        'priority': selectedPriority ?? 'Mittelschwer',
                        'date': _selectedDay?.toIso8601String() ?? DateTime.now().toIso8601String(),
                        'SenderID': widget.userID,
                        'RecieverID': widget.assignedWorkers.join(','), // Liste in String konvertieren
                      };

                      setState(() {
                        if (widget.events[_selectedDay] == null) {
                          widget.events[_selectedDay!] = [];
                        }
                        widget.events[_selectedDay]!.add(newTask);
                        _updateSelectedEvents();
                      });

                      _addTaskToAppwrite(newTask); // Aufgabe hinzufügen
                      Navigator.of(context).pop(); // Dialog schließen
                    }
                  },
                  child: Text(existingTask == null ? 'Hinzufügen' : 'Speichern'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Abbrechen'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  // Ankündigungs Dialog anzeigen
  void _showAnnouncementDialog() {
    final TextEditingController titleController = TextEditingController(); // Controller für Titel
    final TextEditingController descriptionController = TextEditingController(); // Controller für Beschreibung

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Neue Ankündigung hinzufügen'),
          content: SingleChildScrollView( // Um Überlauf zu handhaben
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(hintText: 'Titel eingeben'), // Hinweis für Titel
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(hintText: 'Beschreibung eingeben'), // Hinweis für Beschreibung
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (titleController.text.isNotEmpty && descriptionController.text.isNotEmpty) {
                  final newAnnouncement = {
                    'title': titleController.text,
                    'description': descriptionController.text,
                    'date': _selectedDay != null ? _selectedDay!.toIso8601String() : DateTime.now().toIso8601String(),
                    'creator': widget.userID, // Annahme: Der aktuelle Benutzer ist der Ersteller
                  };

                  setState(() {
                    widget.announcements.add(newAnnouncement);
                    print(widget.announcements);
                  });

                  _addAnnouncementToAppwrite(newAnnouncement);
                  print("looolo");
                }

                Navigator.of(context).pop();
              },
              child: Text('Hinzufügen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }

  // FAB Optionen anzeigen
  void _showFabOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.task),
              title: Text('Aufgabe hinzufügen'),
              onTap: () {
                Navigator.of(context).pop();
                _showTaskDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.announcement),
              title: Text('Ankündigung hinzufügen'),
              onTap: () {
                Navigator.of(context).pop();
                _showAnnouncementDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.share),
              title: Text('Todo teilen'),
              onTap: () {
                Navigator.of(context).pop();
                // Implementieren Sie eine Methode zum Teilen von Todos, falls gewünscht
                // Zum Beispiel könnten Sie ein spezielles Sharing-Dialog öffnen
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    CalendarFormat _calendarFormat = CalendarFormat.month; // Standardmäßig Monatsansicht
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Kalender', style: TextStyle(color: AppColors.mainColor),),
      ),
      body: Column(
        children: [
          IconButton(
            icon: Icon(_isCalendarVisible ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                _isCalendarVisible = !_isCalendarVisible;
              });
            },
            tooltip: _isCalendarVisible ? 'Kalender ausblenden' : 'Kalender anzeigen',
          ),

          if (_isCalendarVisible)
            Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mainColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.thirdColor,
                    blurRadius: 10.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(Duration(days: 365)),
                lastDay: DateTime.now().add(Duration(days: 365)),
                focusedDay: _selectedDay ?? DateTime.now(),
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: AppColors.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.inactiveIconColor,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  titleCentered: true,
                ),
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month'
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _updateSelectedEvents();
                  });
                },
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              ),
            ),

          Expanded(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _selectedEvents,
              builder: (context, events, _) {
                final announcements = _getAnnouncementsForDay(_selectedDay);

                return ListView(
                  children: [
                    if (announcements.isNotEmpty)
                      ...announcements.map((announcement) {
                        return Card(
                          color: Colors.cyan,
                          child: ListTile(
                            title: Text(announcement['title'] ?? 'No Title', style: TextStyle(color: AppColors.secondColor),),
                            subtitle: Text(announcement['description'] ?? 'No Description', style: TextStyle(color: AppColors.secondColor),),
                            iconColor: AppColors.secondColor,
                            leading: Icon(Icons.announcement),
                            trailing: IconButton(
                              onPressed: () {}, 
                              icon: Icon(Icons.more))
                              ,
                          ),
                        );
                      }).toList(),
                    ...events.map((event) {
                      String creatorId = event['creator'] ?? 'No Sender';
                      String creatorName = getUserName(creatorId);

                      List<String> recieverIds = List<String>.from(event['recievers'] ?? []);
                      String recieverNames = getRecieverNames(recieverIds);

                      return Card(
                        color: AppColors.mainColor,
                        child: ListTile(
                          title: Text(event['text'] ?? 'No Task', style: TextStyle(color: AppColors.secondColor),),
                          subtitle: Text(
                            'Zeit: ${event['time'] ?? 'Keine Zeit'} | Priorität: ${event['priority'] ?? 'Keine Priorität'} | Erstellt: $creatorName | Empfänger: $recieverNames'
                            , style: TextStyle(color: AppColors.secondColor),
                          ),
                          iconColor: Colors.indigo,
                          leading: Icon(Icons.task),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    widget.events[_selectedDay]?.remove(event);
                                    _updateSelectedEvents();
                                  });
                                  _deleteTaskFromAppwrite(event['documentId']);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.share, color: Colors.blue),
                                onPressed: () {
                                  _shareTodo(event);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            _showTaskDialog(
                              existingTask: event['text'],
                              existingPriority: event['priority'],
                              existingTime: event['time'],
                            );
                          },
                        ),
                      );
                    }).toList(),

                    SizedBox(height: 100), // Abstand zwischen Buttons
                  ],
                );
              },
            ),
          ),

        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedDay != null) ...[
            FloatingActionButton(
              onPressed: _showFabOptions,
              child: Icon(Icons.add, color: Colors.white),
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              tooltip: 'Optionen anzeigen',
            ),
            SizedBox(height: 16), // Abstand zwischen Buttons
          ],
                    SizedBox(height: 100), // Abstand zwischen Buttons
        ],
      ),
    );
  }
}