import 'package:flutter/material.dart';
import 'package:skilldev_mobapp/login/loginpage.dart';

void main() {
  runApp(MaterialApp(
    initialRoute: '/',
    routes: {
      '/': (context) => LoginPage(),
      '/login/loginpage': (context) => LoginPage(),  // Define the correct login route
    },
    onUnknownRoute: (settings) => MaterialPageRoute(
      builder: (context) => Scaffold(
        body: Center(child: Text('Route not found: ${settings.name}')),
      ),
    ),
  ));
}
