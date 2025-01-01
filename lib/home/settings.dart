import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SettingsPage extends StatefulWidget {
  final String username;
  final String userId;

  const SettingsPage({
    Key? key,
    required this.username,
    required this.userId,
  }) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'English';
  double _textSize = 1.0;

  final List<String> _availableLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese'
  ];

   @override
  void initState() {
    super.initState();
    // Validate userId here instead
    if (widget.userId.isEmpty) {
      print('Error: Empty userId detected in SettingsPage');
      // Add post-frame callback to handle navigation after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid user ID. Please login again.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final response = await http.post(
        Uri.parse('http://bunn.helioho.st/settings.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': widget.userId,
          'action': 'load'
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success']) {
          setState(() {
            _notificationsEnabled = responseData['settings']['notificationsEnabled'] ?? true;
            _emailNotificationsEnabled = responseData['settings']['emailNotificationsEnabled'] ?? true;
            _darkModeEnabled = responseData['settings']['darkModeEnabled'] ?? false;
            _selectedLanguage = responseData['settings']['selectedLanguage'] ?? 'English';
            _textSize = responseData['settings']['textSize']?.toDouble() ?? 1.0;
          });
        }
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      // Debug prints before creating request
      print('Starting _saveSettings');
      print('Current userId: ${widget.userId}');
      print('Current userId type: ${widget.userId.runtimeType}');

      // Validate userId
      if (widget.userId.isEmpty) {
        print('Error: userId is empty');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: User ID is missing')),
        );
        return;
      }

      final requestBody = {
        'userId': widget.userId,
        'notificationsEnabled': _notificationsEnabled,
        'emailNotificationsEnabled': _emailNotificationsEnabled,
        'darkModeEnabled': _darkModeEnabled,
        'selectedLanguage': _selectedLanguage,
        'textSize': _textSize,
      };
      
      // Debug print entire request
      print('Full request body:');
      requestBody.forEach((key, value) {
        print('$key: $value (${value.runtimeType})');
      });

      final response = await http.post(
        Uri.parse('http://bunn.helioho.st/settings.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      print('Response headers: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'])),
          );
        } else {
          throw Exception(responseData['message']);
        }
      } else {
        throw Exception('Failed to save settings: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception in _saveSettings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Color.fromARGB(255, 110, 227, 192),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserSection(),
            _buildDivider(),
            _buildNotificationSection(),
            _buildDivider(),
            _buildAppearanceSection(),
            _buildDivider(),
            _buildLanguageSection(),
            _buildDivider(),
            _buildAboutSection(),
            SizedBox(height: 20),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSection() {
    return _buildSection(
      'Account',
      [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Color.fromARGB(255, 110, 227, 192),
            child: Icon(Icons.person, color: Colors.white),
          ),
          title: Text(widget.username),
          subtitle: Text('Tap to edit profile'),
          onTap: () {
            // Navigate to profile edit page
          },
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return _buildSection(
      'Notifications',
      [
        SwitchListTile(
          title: Text('Push Notifications'),
          subtitle: Text('Receive push notifications'),
          value: _notificationsEnabled,
          activeColor: Color.fromARGB(255, 110, 227, 192),
          onChanged: (bool value) {
            setState(() {
              _notificationsEnabled = value;
            });
          },
        ),
        SwitchListTile(
          title: Text('Email Notifications'),
          subtitle: Text('Receive email updates'),
          value: _emailNotificationsEnabled,
          activeColor: Color.fromARGB(255, 110, 227, 192),
          onChanged: (bool value) {
            setState(() {
              _emailNotificationsEnabled = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return _buildSection(
      'Appearance',
      [
        SwitchListTile(
          title: Text('Dark Mode'),
          subtitle: Text('Enable dark theme'),
          value: _darkModeEnabled,
          activeColor: Color.fromARGB(255, 110, 227, 192),
          onChanged: (bool value) {
            setState(() {
              _darkModeEnabled = value;
            });
          },
        ),
        ListTile(
          title: Text('Text Size'),
          subtitle: Text('Adjust the text size'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.remove),
                onPressed: () {
                  setState(() {
                    _textSize = (_textSize - 0.1).clamp(0.8, 1.4);
                  });
                },
              ),
              Text('${(_textSize * 100).round()}%'),
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    _textSize = (_textSize + 0.1).clamp(0.8, 1.4);
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSection() {
    return _buildSection(
      'Language',
      [
        ListTile(
          title: Text('App Language'),
          subtitle: Text(_selectedLanguage),
          trailing: DropdownButton<String>(
            value: _selectedLanguage,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedLanguage = newValue;
                });
              }
            },
            items: _availableLanguages
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildSection(
      'About',
      [
        ListTile(
          title: Text('App Version'),
          subtitle: Text('1.0.0'),
          trailing: Icon(Icons.info_outline),
        ),
        ListTile(
          title: Text('Terms of Service'),
          trailing: Icon(Icons.arrow_forward_ios),
          onTap: () {
            // Navigate to Terms of Service
          },
        ),
        ListTile(
          title: Text('Privacy Policy'),
          trailing: Icon(Icons.arrow_forward_ios),
          onTap: () {
            // Navigate to Privacy Policy
          },
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 110, 227, 192),
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton(
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color.fromARGB(255, 110, 227, 192),
          minimumSize: Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          'Save Changes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}