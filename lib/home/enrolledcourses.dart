import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'modules.dart';

class EnrolledCoursesPage extends StatefulWidget {
  final String userId;

  const EnrolledCoursesPage({Key? key, required this.userId}) : super(key: key);

  @override
  _EnrolledCoursesPageState createState() => _EnrolledCoursesPageState();
}

class _EnrolledCoursesPageState extends State<EnrolledCoursesPage> {
  List<Map<String, dynamic>> _enrolledCourses = [];
  Map<String, bool> _courseCompletionStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEnrolledCourses();
  }

  Future<void> _checkCourseCompletion(String courseId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://bunn.helioho.st/course_completion.php?course_id=$courseId&user_id=${widget.userId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _courseCompletionStatus[courseId] = data['is_completed'];
          });
        }
      }
    } catch (e) {
      print('Error checking course completion: $e');
    }
  }

    Future<void> _loadEnrolledCourses() async {
    try {
      final response = await http.get(
        Uri.parse('http://bunn.helioho.st/enroll.php?user_id=${widget.userId}')
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _enrolledCourses = List<Map<String, dynamic>>.from(data['courses']);
            _isLoading = false;
          });
          
          
        } else {
          throw Exception(data['message'] ?? 'Failed to load courses');
        }
      } else {
        throw Exception('Failed to load enrolled courses');
      }
    } catch (e) {
      print('Error loading enrolled courses: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Widget _buildProgressIndicator(String courseId) {
  final isCompleted = _courseCompletionStatus[courseId] ?? false;
  
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isCompleted 
        ? Colors.green.withOpacity(0.1) 
        : Color.fromARGB(255, 110, 227, 192).withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isCompleted 
          ? Colors.green 
          : Color.fromARGB(255, 110, 227, 192),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isCompleted ? Icons.check_circle : Icons.schedule,
          size: 16,
          color: isCompleted ? Colors.green : Color.fromARGB(255, 110, 227, 192),
        ),
        SizedBox(width: 4),
        Text(
          isCompleted ? 'Complete' : 'In Progress',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isCompleted ? Colors.green : Color.fromARGB(255, 110, 227, 192),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Enrolled Courses'),
        backgroundColor: Color.fromARGB(255, 110, 227, 192),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _enrolledCourses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        'No enrolled courses yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _enrolledCourses.length,
                  itemBuilder: (context, index) {
                    final course = _enrolledCourses[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: Color.fromARGB(255, 110, 227, 192).withOpacity(0.1),
                              child: Icon(Icons.school, color: Color.fromARGB(255, 110, 227, 192)),
                            ),
                            title: Text(
                              course['title'],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 8),
                                Text(course['description']),
                                SizedBox(height: 12),
                                _buildProgressIndicator(course['id'].toString()),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CourseModulesPage(
                                    courseId: course['id'].toString(),
                                    courseTitle: course['title'],
                                    userId: widget.userId,
                                  ),
                                ),
                              ).then((_) {
                                // Refresh the completion status when returning from course modules
                                _checkCourseCompletion(course['id'].toString());
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}