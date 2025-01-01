import 'package:flutter/material.dart';
import 'package:skilldev_mobapp/home/certificates.dart';
import 'package:skilldev_mobapp/home/chat.dart';
import 'package:skilldev_mobapp/home/notifications.dart';
import 'package:skilldev_mobapp/home/enroll.dart';
import 'package:skilldev_mobapp/home/settings.dart';
import 'package:skilldev_mobapp/login/logout.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;

class HomePage extends StatefulWidget {
  final String email;
  final String password;
  final String username;
  final String? profileImagePath;
  final String userId;

  const HomePage({
    Key? key, // Add Key? key parameter here
    required this.email,
    required this.password,
    required this.username,
    required this.userId,
    this.profileImagePath,
  }) : super(key: key); // Pass key to the super constructor

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String _email;
  late String _username;
  late String _userId; // Define the _userId variable
  late Widget _profileImageWidget;

  @override
  void initState() {
    super.initState();

    // Validate userId
    if (widget.userId.isEmpty) {
      print('Error: Empty userId detected in HomePage');
      // Add post-frame callback to handle navigation after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid user ID. Please login again.')),
        );
        Navigator.of(context).pushReplacementNamed('/'); // or your login route
      });
    }

    _email = widget.email;
    _username = widget.username;
    _userId = widget.userId; // Assign the widget.userId to the _userId variable
    _initializeProfileImage();
  }

  void _initializeProfileImage() {
    if (widget.profileImagePath != null && widget.profileImagePath!.isNotEmpty) {
      if (kIsWeb) {
        _profileImageWidget = Image.network(
          widget.profileImagePath!,
          fit: BoxFit.cover,
        );
      } else {
        _profileImageWidget = Image.file(
          File(widget.profileImagePath!),
          fit: BoxFit.cover,
        );
      }
    } else {
      _profileImageWidget = Image.asset(
        'assets/images/profile.jpg',
        fit: BoxFit.cover,
      );
    }
  }

  void _showNavigationMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Settings
              ListTile(
                leading: Icon(
                  Icons.settings,
                  color: Color.fromARGB(255, 110, 227, 192),
                ),
                title: Text(
                  'Settings',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  // Debug prints before navigation
                  print('HomePage - Current userId: $_userId');
                  print('HomePage - userId type: ${_userId.runtimeType}');
                  print('HomePage - userId empty? ${_userId.isEmpty}');
                  
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        print('HomePage - Building SettingsPage with userId: $_userId');
                        return SettingsPage(
                          username: _username,
                          userId: _userId,
                        );
                      },
                    ),
                  );
                },
              ),
              Divider(),
              // Logout
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Confirm Logout'),
                        content: Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              LogoutHandler.logout(context);
                            },
                            child: Text(
                              'Logout',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 110, 227, 192),
                  Colors.white,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _showNavigationMenu(context),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.menu, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        _username,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(24),
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      children: [
                        _buildQuickActionCard(
                          'Certificates',
                          Icons.workspace_premium,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CertificatesPage(
                          
                                  userId: _userId, username: '',
                                ),
                              ),
                            );
                          },
                        ),
                       _buildQuickActionCard(
                            'Enroll',
                            Icons.school,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EnrollmentPage(
                                    userId: _userId,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildQuickActionCard(
                            'Notifications',
                            Icons.notifications,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const NotificationsPage()),
                              );
                            },
                          ),
                        _buildQuickActionCard(
                          'Chat',
                          Icons.chat,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  username: _username,
                                  userId: _userId,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 110, 227, 192).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: Color.fromARGB(255, 110, 227, 192),
              ),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}