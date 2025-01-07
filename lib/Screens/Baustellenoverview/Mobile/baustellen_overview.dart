import 'package:appwrite/models.dart';
import 'package:baustellenapp/Constants/colors.dart';
import 'package:baustellenapp/DataBase/appwrite_constant.dart';
import 'package:baustellenapp/DataBase/data_fetcher.dart';
import 'package:baustellenapp/Screens/AddBaustellen/Mobile/add_baustellen_mobile.dart';
import 'package:baustellenapp/Screens/ProjectDetails/Mobile/project_details.dart';
import 'package:baustellenapp/Widgets/trapezium_clippers.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';

Client client = Client()
  ..setEndpoint(AppwriteConstants.endPoint) // Your Appwrite API endpoint
  ..setProject(AppwriteConstants.projectId); // Your project ID

Databases databases = Databases(client); // Initialize the Appwrite database service

class Overview extends StatefulWidget {
  final Client client;
  final String userID;
  Future<List<Map<String, String>>> projectNames;
  bool isDataFetched;
  final Document userDoc;

  Overview({
    super.key,
    required this.client,
    required this.userID,
    required this.projectNames,
    required this.isDataFetched,
    required this.userDoc,
  });

  @override
  _OverviewState createState() => _OverviewState();
}

class _OverviewState extends State<Overview> {
  late Databases databases;
  String userAddress = '';

  @override
  void initState() {
    super.initState();
    databases = Databases(widget.client);
    if (!widget.isDataFetched) {
      print("\nFetched"*100);
      _initializeData();
    }
  }

  Future<void> _initializeData() async {
    await fetchUserAddressAndProjects();
    setState(() {
      widget.isDataFetched = true;  // Set flag to true after data is fetched
    });
  }

  Future<void> fetchUserAddressAndProjects() async {
    try {
      String address = await fetchUserAddress(databases, widget.userID);
      List<Map<String, String>> projects = await fetchProjectNames(databases, widget.userID, widget.userDoc);

      setState(() {
        userAddress = address;
        widget.projectNames = Future.value(projects);  // Only set it once data is fetched
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: FutureBuilder<List<Map<String, String>>>(
        future: widget.projectNames,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Column(
              children: [
                Center(child: Text('Error: ${snapshot.error}')),
                // Floating action button for adding project...
                FloatingActionButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddBaustelleScreen(client: widget.client, userId: widget.userID,),
                      ),
                    );
                    if (result == true) {
                      setState(() {
                        widget.projectNames = fetchProjectNames(databases, widget.userID, widget.userDoc);  // Refresh data if added
                      });
                    }
                  },
                  backgroundColor: AppColors.mainColor,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                SizedBox(height: screenWidth/3),
              ],
            );
          }

          final projects = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                      left: screenWidth / 15, right: screenWidth / 15, top: screenWidth / 15, bottom: screenWidth / 15),
                  child: Row(
                    children: [
                      Text(
                        "Hello!",
                        style: TextStyle(
                          color: AppColors.mainColor,
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth / 20,
                        ),
                      ),
                      Spacer(),
                      Text(
                        "Project Overview",
                        style: TextStyle(
                          color: AppColors.mainColor,
                          fontWeight: FontWeight.w700,
                          fontSize: screenWidth / 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1.5,
                  color: AppColors.thirdColor,
                ),
                projects.isEmpty
                    ? const Center(child: Text('No projects available'))
                    : ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          bool isEven = index % 2 == 0;
                          return GestureDetector(
                            onTap: () async {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProjectDetail(
                                    projectName: projects[index]['name'] ?? 'Unknown',
                                    projectAdress: projects[index]['address'] ?? 'Unknown',
                                    currentBaustelleId: projects[index]['id'] ?? 'Unknown',
                                    userID: widget.userID,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(width: 1.5, color: AppColors.thirdColor),
                                  left: BorderSide(width: 1.5, color: AppColors.thirdColor),
                                  right: BorderSide(width: 1.5, color: AppColors.thirdColor),
                                ),
                              ),
                              child: Column(
                                children: isEven
                                    ? [
                                        Stack(
                                          children: <Widget>[
                                            SizedBox(
                                              height: screenWidth/3.5,
                                              width: double.infinity,
                                              child: Image.network(
                                                projects[index]['imageUrl'] ?? '',
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                                              ),
                                            ),
                                            ClipPath(
                                              clipper: TrapeziumClipper(),
                                              child: Container(
                                                color: AppColors.secondColor,
                                                padding: const EdgeInsets.all(8.0),
                                                width: double.infinity,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(left: screenWidth/2.8),
                                                      child: Text(
                                                        projects[index]['name'] ?? 'Unknown',
                                                        style: const TextStyle(
                                                          color: AppColors.mainColor,
                                                          fontSize: 22,
                                                          fontWeight: FontWeight.w200,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsets.only(left: screenWidth/1.5),
                                                      child: Text(
                                                        projects[index]['projectLeader'] ?? 'No Project Leader',
                                                        style: const TextStyle(
                                                          color: AppColors.thirdColor,
                                                          fontSize: 14,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsets.only(left: screenWidth/1.5),
                                                      child: Text(
                                                        projects[index]['address'] ?? 'No Address',
                                                        style: const TextStyle(
                                                          color: AppColors.inactiveIconColor,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      ]
                                    : [
                                        Stack(
                                          children: <Widget>[
                                            SizedBox(
                                              height: 136,
                                              width: double.infinity,
                                              child: Image.network(
                                                projects[index]['imageUrl'] ?? '',
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                                              ),
                                            ),
                                            ClipPath(
                                              clipper: TrapeziumClipper2(),
                                              child: Container(
                                                color: AppColors.secondColor,
                                                padding: const EdgeInsets.all(8.0),
                                                width: double.infinity,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.only(right: 140.0),
                                                      child: Text(
                                                        projects[index]['name'] ?? 'Unknown',
                                                        style: const TextStyle(
                                                          color: AppColors.mainColor,
                                                          fontSize: 22,
                                                          fontWeight: FontWeight.w200,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.only(right: 200.0),
                                                      child: Text(
                                                        projects[index]['projectLeader'] ?? 'No Project Leader',
                                                        style: const TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 14,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.only(right: 210.0),
                                                      child: Text(
                                                        projects[index]['address'] ?? 'No Address',
                                                        style: const TextStyle(
                                                          color: AppColors.inactiveIconColor,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
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
                      ),
                FloatingActionButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddBaustelleScreen(client: widget.client, userId: widget.userID,),
                      ),
                    );
                    if (result == true) {
                      setState(() {
                        widget.projectNames = fetchProjectNames(databases, widget.userID, widget.userDoc);  // Refresh data if added
                      });
                    }
                  },
                  backgroundColor: AppColors.mainColor,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}
