import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:baustellenapp/Constants/colors.dart';
import 'package:baustellenapp/DataBase/appwrite_constant.dart';
import 'package:baustellenapp/DataBase/appwrite_service.dart';
import 'package:flutter/material.dart';

class TotalTime extends StatefulWidget {
  final Document userDocument;
  final String userid;
  const TotalTime({
    super.key,
    required this.userDocument,
    required this.userid
  });

  @override
  State<TotalTime> createState() => _TotalTimeState();
}

class _TotalTimeState extends State<TotalTime> {
  late Client _client;
  late Databases _databases;
  int total = 0;
  late AppwriteService _appwriteService;
  Map<DateTime, List<Map<String, dynamic>>> timesSaved = {};

  @override
  void initState() {
    super.initState();
    _initializeAppwrite();
    _fetchEvents(widget.userid);
  }



  Future<void> _initializeAppwrite() async {
    _client = Client()
      ..setEndpoint(AppwriteConstants.endPoint)
      ..setProject(AppwriteConstants.projectId);
    _databases = Databases(_client);
    _appwriteService = AppwriteService();
  }

  void _fetchEvents(String currentUserId) async {
    timesSaved.clear();
    int batchSize = 200;
    int page = 0;
    bool hasMoreDocuments = true;

    try {
      while (hasMoreDocuments) {
        final response = await _databases.listDocuments(
          databaseId: AppwriteConstants.dbId,
          collectionId: AppwriteConstants.arbeitszeitCollectionID,
          queries: [
            Query.limit(batchSize),
            Query.offset(page * batchSize),
          ],
        );

        if (response.documents.length < batchSize) {
          hasMoreDocuments = false;
        }

        for (var doc in response.documents) {
          DateTime date = DateTime.parse(doc.data['Datum']);
          String userid = doc.data['UserID'] ?? 'No Task';
          int arbeitsDauer = doc.data['ArbeitDauer'] ?? 0;
          int pauseDauer = doc.data['PauseDauer'] ?? 0;

          if (userid == currentUserId) {
            timesSaved[date] = (timesSaved[date] ?? [])..add({
              'userid': userid,
              'arbeitsDauer': arbeitsDauer,
              'date': date,
              'pauseDauer': pauseDauer,
            });
            total = total + arbeitsDauer;
          }
        }
        page++;
      }
      setState(() {}); // UI nach dem Abrufen der Daten aktualisieren
    } catch (e) {
      print('Error fetching tasks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sortiere die Daten nach Datum in absteigender Reihenfolge
    List<DateTime> sortedDates = timesSaved.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Absteigend (neueste zuerst)

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text('Arbeitszeiten'),
        backgroundColor: AppColors.mainColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titel mit dem Namen des Benutzers
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.userDocument.data["Name"],
                style: const TextStyle(
                  color: AppColors.mainColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            
            Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Total: ${total}Min", style: const TextStyle(
                    color: AppColors.mainColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w200,
                  ),),
            ),
            Divider(),

            // ListView.builder zur Anzeige der Arbeitszeiten
            timesSaved.isEmpty
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, index) {
                      DateTime date = sortedDates[index];
                      List<Map<String, dynamic>> times = timesSaved[date]!;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16.0),
                          title: Text(
                            'Datum: ${date.toLocal().toString().split(' ')[0]}', // Zeigt das Datum im Format: YYYY-MM-DD
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...times.map((time) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    'Arbeitszeit: ${time['arbeitsDauer']} Min, Pause: ${time['pauseDauer']} Min',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
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
