// data_fetcher.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:baustellenapp/DataBase/appwrite_constant.dart';
import 'package:baustellenapp/Screens/Baustellenoverview/Mobile/baustellen_overview.dart';
import 'package:baustellenapp/Screens/Chatoverview/Mobile/chat_overview.dart';

Future<String> fetchUserAddress(Databases databases, String userID) async {
  try {
    final response = await databases.getDocument(
      databaseId: AppwriteConstants.dbId,
      collectionId: AppwriteConstants.usercollectionId,
      documentId: userID,
    );
    return response.data['Adresse'] ?? '';
  } catch (e) {
    return '';
  }
}

Future<List<Map<String, String>>> fetchProjectNames(Databases databases, String userId, Document userDoc) async {
  try {
    final response = await databases.listDocuments(
      databaseId: AppwriteConstants.dbId,
      collectionId: AppwriteConstants.baustellenoverviewCollectionId,
    );

    List<Map<String, String>> projects = [];
    for (var doc in response.documents) {
      String name = doc.data['Name'] ?? 'Unknown';
      String address = doc.data['Adress'] ?? 'No Address';
      String projectLeader = doc.data['Projektleiter'] ?? 'Unknown';
      String? imageID = doc.data['ImageID']; // Assuming ImageID exists in the collection
      String? fetched_userId = doc.data['UserId']; // Assuming ImageID exists in the collection

      String imageUrl = imageID != null
          ? 'https://cloud.appwrite.io/v1/storage/buckets/${AppwriteConstants.storageBucketId}/files/$imageID/view?project=${AppwriteConstants.projectId}'
          : 'https://via.placeholder.com/150'; // Fallback URL
      
      if (userId == fetched_userId)
      projects.add({
        'name': name,
        'address': address,
        'projectLeader': projectLeader,
        'id': doc.$id,
        'imageUrl': imageUrl, // Add the image URL
      });
      else if (userDoc.data["AssignedTo"] == doc.$id)
      projects.add({
        'name': name,
        'address': address,
        'projectLeader': projectLeader,
        'id': doc.$id,
        'imageUrl': imageUrl, // Add the image URL
      });
      else
      print("$userId | ${fetched_userId}");
    }
    return projects;
  } catch (e) {
    return [];
  }
}


  /// Fetches chat conversations and all users from Appwrite
  Future<void> fetchChats(currentUserID, conversations, isLoading, chatSubscription) async {
    try {
      // Fetch all users excluding the current user
      final usersResponse = await databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.usercollectionId,
      );

      List<ChatConversation> allUsers = [];

      for (var doc in usersResponse.documents) {
        String userID = doc.$id;
        if (userID == currentUserID) {
          continue; // Skip the current user
        }

        String name = doc.data['Name'] ?? 'Unknown';
        String? avatarUrl = doc.data['avatarUrl'];

        allUsers.add(ChatConversation(
          id: userID,
          name: name,
          lastMessage: '',
          lastMessageTime: DateTime.fromMillisecondsSinceEpoch(0),
          avatarUrl: avatarUrl,
          isImage: false,
          isTodo: false,
          unreadCount: 0, // Initialize as 0
        ));
      }

      // Fetch messages where current user is sender or receiver
      final senderResponse = await databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.messagecollectionID,
        queries: [
          Query.equal('SenderID', currentUserID),
        ],
      );

      final receiverResponse = await databases.listDocuments(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.messagecollectionID,
        queries: [
          Query.equal('RecieverID', currentUserID),
        ],
      );

      // Combine messages
      final allMessages = [
        ...senderResponse.documents,
        ...receiverResponse.documents
      ];
      print('Total messages fetched: ${allMessages.length}');
      for (var message in allMessages) {
        print('Message Data: ${message.data}');
      }

      // Process messages to group them into conversations
      Map<String, List<Document>> conversationsMap = {};

      for (var doc in allMessages) {
        String? senderID = doc.data['SenderID'];
        String? receiverID = doc.data['RecieverID'];
        if (senderID == null || receiverID == null) {
          continue;
        }

        String otherUserID;
        if (senderID == currentUserID) {
          otherUserID = receiverID;
        } else {
          otherUserID = senderID;
        }

        if (otherUserID.isEmpty) {
          continue;
        }

        if (!conversationsMap.containsKey(otherUserID)) {
          conversationsMap[otherUserID] = [];
        }

        conversationsMap[otherUserID]!.add(doc);
      }

      // Now merge conversations with users
      List<ChatConversation> fetchedConversations = [];

      for (var user in allUsers) {
        String userID = user.id;

        if (conversationsMap.containsKey(userID)) {
          List<Document> messages = conversationsMap[userID]!;

          // Sort messages by date to get the latest message
          messages.sort((a, b) {
            String? datetimeA = a.data['\$createdAt']; // Use 'createdAt' field
            String? datetimeB = b.data['\$createdAt'];

            DateTime dateA = _parseDatetime(datetimeA);
            DateTime dateB = _parseDatetime(datetimeB);
            return dateB.compareTo(dateA);
          });

          // Get the latest message
          var latestMessageDoc = messages.first;
          bool isImage = latestMessageDoc.data['Image'] ?? false;
          bool isTodo = latestMessageDoc.data['isTodo'] ?? false;
          String lastMessage;
          if (isImage) {
            lastMessage = 'Foto';
          } else {
            lastMessage = latestMessageDoc.data['Text'] ?? '';
          }
          String? datetimeString =
              latestMessageDoc.data['\$createdAt']; // Use 'createdAt'
          DateTime lastMessageTime = _parseDatetime(datetimeString);

          int unreadCount = messages.where((msg) {
            return msg.data['isRead'] == false &&
                msg.data['SenderID'] == userID;
          }).length;

          // Update user with conversation details
          fetchedConversations.add(ChatConversation(
            id: userID,
            name: user.name,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            avatarUrl: user.avatarUrl,
            isImage: isImage,
            isTodo: isTodo,
            unreadCount: unreadCount, // Set unread count
          ));
        } else {
          // No conversation, keep the user details with unreadCount = 0
          fetchedConversations.add(user);
        }
      }

      // Sort the conversations by lastMessageTime descending, then by name
      fetchedConversations.sort((a, b) {
        if (a.lastMessageTime.isAfter(b.lastMessageTime)) {
          return -1;
        } else if (a.lastMessageTime.isBefore(b.lastMessageTime)) {
          return 1;
        } else {
          return a.name.compareTo(b.name);
        }
      });
      
      conversations.clear();
      conversations.addAll(fetchedConversations);
      isLoading = false;

    } catch (e) {
        isLoading = false;
    }
  }
  /// Sets up real-time updates for chat conversations
  void setupRealtimeUpdates(chatSubscription, currentUserID, conversation) {
    final realtime = Realtime(client);

    chatSubscription = realtime.subscribe([
      'databases.${AppwriteConstants.dbId}.collections.${AppwriteConstants.messagecollectionID}.documents',
    ]);

    chatSubscription!.stream.listen((event) {
      handleRealtimeEvent(event, currentUserID, conversation);
    });
  }


   /// Parses the createdAt string into a DateTime object
  DateTime _parseDatetime(String? datetimeString) {
    if (datetimeString == null || datetimeString.isEmpty) {
      print('createdAt string is null or empty. Returning default date.');
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      // Parse the ISO 8601 string directly
      DateTime parsedDate = DateTime.parse(datetimeString).toLocal();
      print('Parsed datetime using ISO 8601: $parsedDate');
      return parsedDate;
    } catch (e) {
      print('ISO 8601 parsing failed: $e');
      // Return default date if parsing fails
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }


 /// Handles real-time events from Appwrite
  void handleRealtimeEvent(RealtimeMessage event, currentUserID, conversations) async {
    final eventType = event.events.first;
    final payload = event.payload;

    // Check if the message involves the current user
    if (payload['SenderID'] != currentUserID &&
        payload['RecieverID'] != currentUserID) {
      return;
    }

    String otherUserID = payload['SenderID'] == currentUserID
        ? payload['RecieverID']
        : payload['SenderID'];

    if (eventType.contains('.create') || eventType.contains('.update')) {
      await addOrUpdateConversationFromEvent(payload, otherUserID, eventType, conversations);
    } else if (eventType.contains('.delete')) {
      // Handle message deletion if necessary
    }
  }

/// Adds or updates a conversation based on real-time events
  Future<void> addOrUpdateConversationFromEvent(
      Map<String, dynamic> data, String otherUserID, String eventType, conversations) async {
    String? datetimeString = data['\$createdAt']; // Use 'createdAt' field
    DateTime messageTime = _parseDatetime(datetimeString);
    bool isImage = data['Image'] ?? false;
    bool isTodo = data['isTodo'] ?? false;
    String lastMessage;
    if (isImage) {
      lastMessage = 'Foto';
    } else {
      lastMessage = data['Text'] ?? '';
    }

    bool isUnread = data['isRead'] == false && data['SenderID'] == otherUserID;

    // Get the other user's name and avatar
    String name = await getUserName(otherUserID);
    String? avatarUrl = await getUserAvatarUrl(otherUserID);

    // Check if the conversation already exists in the list
    int index = conversations.indexWhere((conv) => conv.id == otherUserID);

    if (index != -1) {
      ChatConversation existingConv = conversations[index];
      if (eventType.contains('.create')) {
        // New message created
          conversations[index] = ChatConversation(
            id: otherUserID,
            name: name,
            lastMessage: lastMessage,
            lastMessageTime: messageTime,
            avatarUrl: avatarUrl,
            isImage: isImage,
            isTodo: isTodo,
            unreadCount: isUnread
                ? existingConv.unreadCount + 1
                : existingConv.unreadCount,
          );
      } else if (eventType.contains('.update')) {
        // Message updated (likely marked as read)
        if (data['isRead'] == true && data['SenderID'] == otherUserID) {
            conversations[index] = ChatConversation(
              id: otherUserID,
              name: name,
              lastMessage: lastMessage,
              lastMessageTime: messageTime,
              avatarUrl: avatarUrl,
              isImage: isImage,
              isTodo: isTodo,
              unreadCount: existingConv.unreadCount > 0
                  ? existingConv.unreadCount - 1
                  : 0,
            );
        } else if (isUnread) {
          // New unread message via update (rare case)
            conversations[index] = ChatConversation(
              id: otherUserID,
              name: name,
              lastMessage: lastMessage,
              lastMessageTime: messageTime,
              avatarUrl: avatarUrl,
              isImage: isImage,
              isTodo : isTodo,
              unreadCount: existingConv.unreadCount + 1,
            );
        }
      }
    } else {
      // Add new conversation
        conversations.add(ChatConversation(
          id: otherUserID,
          name: name,
          lastMessage: lastMessage,
          lastMessageTime: messageTime,
          avatarUrl: avatarUrl,
          isImage: isImage,
          isTodo: isTodo,
          unreadCount: isUnread ? 1 : 0,
        ));
    }
    // Sort the conversations by lastMessageTime descending, then by name
      conversations.sort((a, b) {
        if (a.lastMessageTime.isAfter(b.lastMessageTime)) {
          return -1;
        } else if (a.lastMessageTime.isBefore(b.lastMessageTime)) {
          return 1;
        } else {
          return a.name.compareTo(b.name);
        }
      });
  }
  

  /// Gets the user's name from the database
  Future<String> getUserName(String userID) async {
    try {
      final response = await databases.getDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.usercollectionId,
        documentId: userID,
      );
      return response.data['Name'] ?? 'Unknown';
    } catch (e) {
      print('Error fetching user name: $e');
      return 'Unknown';
    }
  }
  /// Gets the user's avatar URL from the database
  Future<String?> getUserAvatarUrl(String userID) async {
    try {
      final response = await databases.getDocument(
        databaseId: AppwriteConstants.dbId,
        collectionId: AppwriteConstants.usercollectionId,
        documentId: userID,
      );
      return response.data['avatarUrl'];
    } catch (e) {
      print('Error fetching user avatar: $e');
      return null;
    }
  }
 