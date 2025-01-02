import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:regexpattern/regexpattern.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/io_client.dart';
import 'dart:io';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class PhotoPermissionHandler {
  static Future<bool> requestPhotoPermission(BuildContext context) async {
    if (Platform.isIOS) {
      return _requestIOSPhotoPermission(context);
    } else if (Platform.isAndroid) {
      return _requestAndroidPhotoPermission(context);
    }
    return false;
  }

  static Future<bool> _requestIOSPhotoPermission(BuildContext context) async {
    final status = await Permission.photos.status;
    if (status.isGranted) return true;
    
    if (status.isPermanentlyDenied) {
      return _handlePermanentlyDenied(context, 'photos');
    }
    
    final result = await Permission.photos.request();
    return _handlePermissionResult(context, result);
  }

  static Future<bool> _requestAndroidPhotoPermission(BuildContext context) async {
    // Try photos permission first (for Android 13+)
    var status = await Permission.photos.status;
    if (status.isGranted) return true;
    
    if (!status.isPermanentlyDenied) {
      final result = await Permission.photos.request();
      if (result.isGranted) return true;
    }

    // If photos permission fails, try storage permission (for older Android versions)
    status = await Permission.storage.status;
    if (status.isGranted) return true;
    
    if (status.isPermanentlyDenied) {
      return _handlePermanentlyDenied(context, 'storage');
    }
    
    final result = await Permission.storage.request();
    return _handlePermissionResult(context, result);
  }

  static Future<bool> _handlePermanentlyDenied(BuildContext context, String permissionType) async {
    final bool shouldOpenSettings = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text(
          'Access to ${permissionType == 'photos' ? 'photos' : 'storage'} is needed to upload your profile picture, ID, and clearance documents. '
          'Please enable it in Settings.'
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Open Settings'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    
    if (shouldOpenSettings == true) {
      await openAppSettings();
      // Recheck permission after returning from settings
      if (Platform.isAndroid) {
        final photosGranted = await Permission.photos.status.isGranted;
        final storageGranted = await Permission.storage.status.isGranted;
        return photosGranted || storageGranted;
      }
      return await Permission.photos.status.isGranted;
    }
    return false;
  }

  static Future<bool> _handlePermissionResult(BuildContext context, PermissionStatus status) async {
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Photo access is required to upload images. '
            'Please grant permission to continue with registration.'
          ),
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
    return status.isGranted;
  }
}

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _passwordVisible = false;          
  bool _confirmPasswordVisible = false;

  String? _errorMessage;
  String? _selectedId;
  String? _selectedClearance;
  
  XFile? _profileImage;
  XFile? _idImage;
  XFile? _clearanceImage;
  
  String? _profileImageName;
  String? _idImageName;
  String? _clearanceImageName;

  final List<String> validIdOptions = ['Passport', 'Voters ID', 'Drivers License'];
  final List<String> clearanceOptions = [ 'Barangay Clearance'];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/loginbackground_nologo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back, color: Colors.black),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                              style: ButtonStyle(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Sign Up',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(width: 24),
                          ],
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  shape: BoxShape.circle,
                                ),
                                child: _profileImage != null
                                    ? ClipOval(
                                        child: kIsWeb
                                            ? Image.network(_profileImage!.path, fit: BoxFit.cover)
                                            : Image.file(File(_profileImage!.path), fit: BoxFit.cover))
                                    : Icon(Icons.person, size: 80, color: Colors.grey[400]),
                              ),
                              if (_profileImage != null)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _profileImage = null;
                                        _profileImageName = null;
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _pickImage('Profile'),
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_profileImageName != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(_profileImageName!,
                                  style: TextStyle(color: Colors.grey[600])),
                            ),
                          ),
                        SizedBox(height: 16),
                        _buildTextField('Username', Icons.account_circle, _usernameController),
                        SizedBox(height: 16),
                        _buildTextField('Email', Icons.email, _emailController),
                        SizedBox(height: 16),
                        _buildTextField('Password', Icons.lock, _passwordController, isPassword: true, isConfirmPassword: false),
                        SizedBox(height: 16),
                        _buildTextField('Confirm Password', Icons.lock, _confirmPasswordController, isPassword: true, isConfirmPassword: true),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        SizedBox(height: 16),
                        _buildDropdownField('Submit Valid ID', validIdOptions, _selectedId, (newValue) {
                          setState(() {
                            _selectedId = newValue;
                          });
                        }),
                        SizedBox(height: 8),
                        _buildImageUploadField('ID', _idImage, _idImageName),
                        SizedBox(height: 16),
                        _buildDropdownField('Proof of Clearance', clearanceOptions, _selectedClearance, (newValue) {
                          setState(() {
                            _selectedClearance = newValue;
                          });
                        }),
                        SizedBox(height: 8),
                        _buildImageUploadField('Clearance', _clearanceImage, _clearanceImageName),
                        SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () {
                            if (_validateInputs()) {
                              _registerUser();
                            } else {
                              // Scroll to the error message
                              Future.delayed(Duration(milliseconds: 100), () {
                                _scrollController.animateTo(
                                  _scrollController.position.maxScrollExtent,
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              });
                            }
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(color: Colors.black),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 110, 227, 192),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, IconData icon, TextEditingController controller, {bool isPassword = false, bool isConfirmPassword = false}) {
  bool isObscureText = isPassword ? (isConfirmPassword ? !_confirmPasswordVisible : !_passwordVisible) : false;
  
  return TextField(
    controller: controller,
    obscureText: isObscureText,
    decoration: InputDecoration(
      fillColor: Colors.white,
      filled: true,
      prefixIcon: Icon(icon),
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                isConfirmPassword
                    ? (_confirmPasswordVisible ? Icons.visibility : Icons.visibility_off)
                    : (_passwordVisible ? Icons.visibility : Icons.visibility_off),
              ),
              onPressed: () {
                setState(() {
                  if (isConfirmPassword) {
                    _confirmPasswordVisible = !_confirmPasswordVisible;
                  } else {
                    _passwordVisible = !_passwordVisible;
                  }
                });
              },
            )
          : null,
    ),
  );
}

  Widget _buildDropdownField(String label, List<String> options, String? selectedValue, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedValue,
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
          items: options.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImageUploadField(String type, XFile? image, String? imageName) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                imageName ?? 'Upload $type Image',
                style: TextStyle(
                  color: image != null ? Colors.black87 : Colors.grey,
                  fontWeight: image != null ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: image != null
                ? IconButton(
                    icon: Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () {
                      setState(() {
                        switch (type) {
                          case 'ID':
                            _idImage = null;
                            _idImageName = null;
                            break;
                          case 'Clearance':
                            _clearanceImage = null;
                            _clearanceImageName = null;
                            break;
                        }
                      });
                    },
                  )
                : IconButton(
                    icon: Icon(Icons.upload_file, color: Colors.blue),
                    onPressed: () => _pickImage(type),
                  ),
          ),
        ],
      ),
    );
  }

  void _showValidationDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Validation Error',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

Future<void> sendEmailConfirmation(String recipientEmail, String username) async {
  final smtpServer = SmtpServer(
    'smtp.mailersend.net',
    username: 'MS_ERvzYj@trial-v69ox15qeyl1785k.mlsender.net',
    password: 'xhNE5HAMBaNVcLJC',
    port: 587,
  );

  final message = Message()
    ..from = Address('no-reply@example.com', 'Registration Confirmation')
    ..recipients.add(recipientEmail)
    ..subject = 'Welcome to our app!'
    ..text = 'Dear $username, thank you for registering with our app.';

  try {
    await send(message, smtpServer);
    print('Email sent!');
  } on MailerException catch (e) {
    print('Message not sent. $e');
    for (var p in e.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
  }
}

   Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    XFile? pickedFile;

    final hasPermission = await PhotoPermissionHandler.requestPhotoPermission(context);
    if (hasPermission) {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    }

    if (pickedFile != null) {
      if (!['jpg', 'jpeg', 'png'].contains(pickedFile.path.split('.').last.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a JPG or PNG image.')),
        );
        return;
      }

      setState(() {
        switch (type) {
          case 'Profile':
            _profileImage = pickedFile;
            _profileImageName = pickedFile?.path.split('/').last;
            break;
          case 'ID':
            _idImage = pickedFile;
            _idImageName = pickedFile?.path.split('/').last;
            break;
          case 'Clearance':
            _clearanceImage = pickedFile;
            _clearanceImageName = pickedFile?.path.split('/').last;
            break;
        }
      });
    }
  }

  Future<void> _registerUser() async {
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('http://bunn.helioho.st/register.php')
    );

    // Add text fields
    request.fields['username'] = _usernameController.text;
    request.fields['email'] = _emailController.text;
    request.fields['password'] = _passwordController.text;

    // Add files with consistent keys
    if (_profileImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'profileImage', 
        _profileImage!.path
      ));
    }

    if (_idImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'id_proof_file', 
        _idImage!.path
      ));
    }

    if (_clearanceImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'proof_clearance_file', 
        _clearanceImage!.path
      ));
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      _handleRegistrationResponse(response);

      // Send confirmation email
      await sendEmailConfirmation(_emailController.text, _usernameController.text);
    } catch (e) {
      print('Error during registration: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleRegistrationResponse(http.Response response) {
  try {
    // Print full response body for comprehensive debugging
    print('Full Response Body: ${response.body}');
    print('Status Code: ${response.statusCode}');

    // Extract only the JSON part of the response
    String responseBody = response.body;
    
    // Find the first '{' and last '}' to isolate JSON
    int startIndex = responseBody.indexOf('{');
    int endIndex = responseBody.lastIndexOf('}');
    
    if (startIndex != -1 && endIndex != -1) {
      responseBody = responseBody.substring(startIndex, endIndex + 1);
    }

    // Try to parse the JSON response
    var jsonResponse;
    try {
      jsonResponse = json.decode(responseBody);
    } catch (parseError) {
      print('JSON Parsing Error: $parseError');
      print('Extracted Response body was: $responseBody'); // Log the extracted response
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error parsing server response. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // More detailed error checking
    if (response.statusCode >= 400 || jsonResponse['success'] != true) {
      // Handle specific error messages from the server
      String errorMessage = jsonResponse['message'] ?? 
                            jsonResponse['error'] ?? 
                            'Registration failed due to an unknown error';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Successful registration
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(jsonResponse['message'] ?? 'Registration successful'),
        backgroundColor: Colors.green,
      ),
    );

    // Send confirmation email
    sendEmailConfirmation(_emailController.text, _usernameController.text);

    // Navigate to login page
    Navigator.pushNamedAndRemoveUntil(
      context, '/login/loginpage', (route) => false,
    );

  } catch (e) {
    // Catch any unexpected errors
    print('Unexpected Error during registration handling: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('An unexpected error occurred. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

   bool _validateInputs() {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (_profileImage == null) {
      _showValidationDialog('Please select a profile image.');
      return false;
    }

    if (_selectedId == null || _selectedClearance == null) {
      _showValidationDialog('Please pick a Valid ID and Proof of Clearance.');
      return false;
    }

    if (_idImage == null || _clearanceImage == null) {
      _showValidationDialog('Please upload both ID and clearance images.');
      return false;
    }

    final emailRegEx = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegEx.hasMatch(email)) {
      _showValidationDialog('Please enter a valid email address.');
      return false;
    }

    if (username.length < 3) {
      _showValidationDialog('Username must be at least 3 characters long.');
      return false;
    }

    if (password != confirmPassword) {
      _showValidationDialog('Password and Confirm Password do not match.');
      return false;
    }

    final passwordRegEx = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    );

    if (!passwordRegEx.hasMatch(password)) {
      _showValidationDialog('Password must be at least 8 characters long, containing an uppercase letter, a lowercase letter, a number, and a special character.');
      return false;
    }

    return true;
  }
}