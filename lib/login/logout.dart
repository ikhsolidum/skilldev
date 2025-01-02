import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/login/loginpage.dart';

class LogoutHandler {
  static Future<void> logout(BuildContext context) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Logging out...'),
              ],
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.grey[800],
          ),
        );
      }

      // Clear stored user data
      try {
        final prefs = await SharedPreferences.getInstance();
        await Future.wait([
          prefs.remove('user_email'),
          prefs.remove('user_token'),
          // Add any other keys you need to clear
        ]);
      } catch (e) {
        debugPrint('Error clearing preferences: $e');
        // Continue with logout even if preferences clear fails
      }

      // Navigate to login page only if context is still valid
      if (context.mounted) {
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginPage(),
          ),
          (Route<dynamic> route) => false,
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully logged out'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      debugPrint('Error during logout: $error');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}