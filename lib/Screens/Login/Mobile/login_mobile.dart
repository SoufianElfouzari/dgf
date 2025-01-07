import 'package:flutter/material.dart';
import 'package:baustellenapp/Constants/colors.dart';
import 'package:baustellenapp/Widgets/navigation_screen.dart';
import 'package:baustellenapp/DataBase/appwrite_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  final AppwriteService _appwriteService = AppwriteService();

  Future<void> _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      // Call login method to get user document and user ID
      final result = await _appwriteService.login(email, password);
      final userDoc = result['userDoc'];
      final userID = result['userID'];

      if (userDoc == null || userID == null) {
        throw Exception('Benutzer nicht gefunden.');
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => NavigationScreen(
            client: _appwriteService.client,
            userDocumet: userDoc,
            userID: userID,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Login', style: TextStyle(color: AppColors.secondColor)),
        backgroundColor: AppColors.mainColor,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.spezialColor.withOpacity(0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'E-Mail',
                        errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Passwort',
                        errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mainColor,
            ),
            onPressed: _login,
            child: const Text('Anmelden', style: TextStyle(color: AppColors.secondColor)),
          ),
        ],
      ),
    );
  }
}
