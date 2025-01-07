import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:baustellenapp/DataBase/appwrite_constant.dart';
import 'package:baustellenapp/Screens/Baustellenoverview/Mobile/baustellen_overview.dart';
import 'package:baustellenapp/Screens/Chatoverview/Mobile/chat_overview.dart';
import 'package:baustellenapp/Screens/Kalender/Mobile/kalender_mobile.dart';
import 'package:baustellenapp/Screens/Settings/Mobile/settings.dart';
import 'package:baustellenapp/Screens/Zeiterfassung/Mobile/zeiterfassung_mobile.dart';
import 'package:flutter/material.dart';
import '../Widgets/bottom_navigation_bar.dart';
import 'package:baustellenapp/Constants/colors.dart';

class NavigationScreen extends StatefulWidget {
  final Client client;
  final String userID;
  final Document userDocumet;

  const NavigationScreen({
    super.key,
    required this.client,
    required this.userID,
    required this.userDocumet,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;
  late String userAddress;
  late Future<List<Map<String, String>>> projectNames;
  List<ChatConversation> conversations = [];

  // Add flags to ensure data is fetched only once
  bool isDataFetched1 = false;
  bool isDataFetched2 = false;
  bool isDataFetched3 = false;
  bool isLoading = false;
  Map<DateTime, List<Map<String, dynamic>>> events = {};
  List<Map<String, dynamic>> announcements = [];
  List<Document> userList = [];
  Map<String, String> userMap = {};
  List<String> assignedWorkers = [];
  

  @override
  void initState() {
    super.initState();

    userAddress = '';
    projectNames = Future.value([]);

    _screens = [
      Overview(client: widget.client, userID: widget.userID, projectNames: projectNames, isDataFetched: isDataFetched1, userDoc: widget.userDocumet,),
      ChatOverviewScreen(client: widget.client, currentUserID: widget.userID, isDataFetched: isDataFetched2, conversations: conversations, isLoading: isLoading, userName: widget.userDocumet.data["Name"],),
      SettingsScreen(currentUserDocument: widget.userDocumet, userid: widget.userID),
      Zeiterfassung(client: widget.client, currentUserDocument: widget.userDocumet, userId: widget.userID),
      Kalender(userID: widget.userID, isDataFetched: isDataFetched3, events: events, announcements: announcements, userList: userList, userMap: userMap, assignedWorkers: assignedWorkers,),
    ];

  }

  void _onItemSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          _screens[_currentIndex],
          PositionedDirectional(
            bottom: 0,
            child: BottomNavigationBarWidget(
              currentIndex: _currentIndex,
              onItemSelected: _onItemSelected,
            ),
          ),
        ],
      ),
    );
  }
}
