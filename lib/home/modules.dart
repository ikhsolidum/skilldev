import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Module {
  final int id;
  final int courseId;
  final String title;
  final String content;
  final String createdAt;
  bool isCompleted;

  Module({
    required this.id,
    required this.courseId,
    required this.title,
    required this.content,
    required this.createdAt,
    this.isCompleted = false,
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      id: int.parse(json['id'].toString()),
      courseId: int.parse(json['course_id'].toString()),
      title: json['title']?.toString() ?? 'Untitled Module',
      content: json['content']?.toString() ?? 'No content available',
      createdAt: json['created_at']?.toString() ?? DateTime.now().toString(),
      isCompleted: json['is_completed'] == '1', // Update this to match your API response
    );
  }
}

class CourseModulesPage extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String userId; // Add userId parameter

  const CourseModulesPage({
    Key? key,
    required this.courseId,
    required this.courseTitle,
    required this.userId, // Make userId required
  }) : super(key: key);

  @override
  _CourseModulesPageState createState() => _CourseModulesPageState();
}

class _CourseModulesPageState extends State<CourseModulesPage> {
  List<Module> _modules = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Set<int> _expandedModules = {};
  bool _isCourseCompleted = false;
  int _completedModules = 0;
  int _totalModules = 0;
  bool _wasCompletedBefore = false;

 @override
void initState() {
  super.initState();
  _fetchModules().then((_) {
    _initializeModuleCounts();
  });
  _checkCourseCompletion();
}

  Future<void> _fetchModules() async {
  try {
    final int? parsedCourseId = int.tryParse(widget.courseId);
    if (parsedCourseId == null) {
      throw Exception('Invalid course ID format');
    }

    final url = Uri.parse(
        'http://bunn.helioho.st/modules.php?course_id=$parsedCourseId&user_id=${widget.userId}');

    print('Fetching modules from: ${url.toString()}');

    final response = await http.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Connection timeout. Please check your internet connection.');
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (!data.containsKey('success') || !data.containsKey('modules')) {
        throw Exception('Invalid response format from server');
      }

      if (data['success'] == true) {
        final modulesList = data['modules'] as List<dynamic>;

        setState(() {
          _modules = modulesList
              .map((moduleJson) {
                try {
                  return Module.fromJson(moduleJson as Map<String, dynamic>);
                } catch (e) {
                  print('Error parsing module: $e');
                  return null;
                }
              })
              .whereType<Module>()
              .toList();

          _isLoading = false;
          _errorMessage = '';
          
          // Initialize counts after modules are loaded
          _totalModules = _modules.length;
          _completedModules = _modules.where((module) => module.isCompleted).length;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load modules';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = 'Server error: ${response.statusCode}';
        _isLoading = false;
      });
    }
  } catch (e) {
    print('Error fetching modules: $e');
    setState(() {
      _errorMessage = e.toString();
      _isLoading = false;
    });
  }
}

Future<void> _showCompletionDialog() async {
    if (!context.mounted) return;
    return showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Complete Course'),
          content: Text('Are you sure you want to mark this course as complete?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Complete'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _markCourseAsCompleted();
              },
            ),
          ],
        );
      },
    );
  }

Future<void> _markCourseAsCompleted() async {
  try {
    final response = await http.post(
      Uri.parse('http://bunn.helioho.st/course_completion.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': widget.userId,  // Send as string, PHP will handle conversion
        'course_id': widget.courseId, // Send as string, PHP will handle conversion
        'action': 'complete_course' // Add action parameter to explicitly mark completion
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Course completion response: $data'); // Debug log
      
      if (data['success']) {
        setState(() {
          _isCourseCompleted = true;
          _wasCompletedBefore = true;
        });

        // Show celebration dialog after state is updated
        if (!context.mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Congratulations! 🎉'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.celebration,
                    size: 64,
                    color: Color.fromARGB(255, 110, 227, 192),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'You\'ve successfully completed this course!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Refresh course completion status after closing dialog
                    _checkCourseCompletion();
                  },
                ),
              ],
            );
          },
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to complete course'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    print('Error marking course as completed: $e');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to mark course as completed: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}


  Future<void> _checkCourseCompletion() async {
    try {
      final url = Uri.parse(
          'http://bunn.helioho.st/course_completion.php?course_id=${widget.courseId}&user_id=${widget.userId}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _isCourseCompleted = data['is_completed'];
            _completedModules = data['completed_modules'];
            _totalModules = data['total_modules'];
          });
        }
      }
    } catch (e) {
      print('Error checking course completion: $e');
    }
  }

  Future<void> _updateCourseCompletion() async {
  try {
    final response = await http.post(
      Uri.parse('http://bunn.helioho.st/course_completion.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': int.parse(widget.userId),
        'course_id': int.parse(widget.courseId),
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() {
          _isCourseCompleted = data['is_completed'];
          _completedModules = data['completed_modules'];
          _totalModules = data['total_modules'];
        });

        if (_isCourseCompleted && !_wasCompletedBefore) {
          _wasCompletedBefore = true;  // Prevent showing multiple times
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Congratulations! Course completed! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  } catch (e) {
    print('Error updating course completion: $e');
  }
}

  Future<void> _toggleModuleCompletion(Module module) async {
  try {
    // First toggle the module completion
    final response = await http.post(
      Uri.parse('http://bunn.helioho.st/module_completion.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': widget.userId,
        'module_id': module.id,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() {
          module.isCompleted = data['completed'];
          // Update completed modules count
          _completedModules = _modules.where((m) => m.isCompleted).length;
        });

        // Now explicitly update course completion status regardless of completion count
        await _updateCourseCompletion();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  } catch (e) {
    print('Error toggling module completion: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to update module status'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// Add this method to initialize the counts in initState
void _initializeModuleCounts() {
  _totalModules = _modules.length;
  _completedModules = _modules.where((module) => module.isCompleted).length;
}


  void _toggleModule(int moduleId) {
    setState(() {
      if (_expandedModules.contains(moduleId)) {
        _expandedModules.remove(moduleId);
      } else {
        _expandedModules.add(moduleId);
      }
    });
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
  title: Text(widget.courseTitle),
  backgroundColor: Color.fromARGB(255, 110, 227, 192),
  actions: [
    if (_completedModules == _totalModules && !_isCourseCompleted)
      TextButton.icon(
        onPressed: () => _showCompletionDialog(),
        icon: Icon(Icons.check_circle_outline, color: Colors.white),
        label: Text(
          'Complete Course',
          style: TextStyle(color: Colors.white),
        ),
      ),
  ],
),
    body: Column(
      children: [
        // Progress indicator section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: _totalModules > 0 ? _completedModules / _totalModules : 0,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromARGB(255, 110, 227, 192),
                ),
                minHeight: 10, // Make the progress bar more visible
              ),
              SizedBox(height: 8),
              Text(
                'Progress: $_completedModules/$_totalModules modules completed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isCourseCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Course Completed! 🎉',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Modules list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchModules,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _modules.isEmpty
                      ? const Center(
                          child: Text(
                            'No modules available for this course',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _modules.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final module = _modules[index];
                            final isExpanded = _expandedModules.contains(module.id);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: Transform.scale(
                                      scale: 1.2,
                                      child: Checkbox(
                                        value: module.isCompleted,
                                        activeColor: Color.fromARGB(255, 110, 227, 192),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        onChanged: (bool? value) {
                                          _toggleModuleCompletion(module);
                                        },
                                      ),
                                    ),
                                    title: Text(
                                      module.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        decoration: module.isCompleted
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        color: module.isCompleted
                                            ? Colors.grey
                                            : Colors.black,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        isExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: Color.fromARGB(255, 110, 227, 192),
                                      ),
                                      onPressed: () => _toggleModule(module.id),
                                    ),
                                  ),
                                  if (isExpanded)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Html(
                                            data: module.content,
                                            style: {
                                              "body": Style(
                                                fontSize: FontSize(14),
                                                padding: HtmlPaddings.zero,
                                                margin: Margins.zero,
                                              ),
                                            },
                                            onLinkTap: (String? url,
                                                Map<String, String> attributes,
                                                element) async {
                                              if (url != null) {
                                                await launchUrlString(url);
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Created: ${module.createdAt}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    ),
  );
}
}