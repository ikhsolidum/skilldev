import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:skilldev_mobapp/home/enrolledcourses.dart';

class Course {
  final String id;
  final String title;
  final String description;
  final String content;
  final String createdAt;
  final String category;
  final bool archived;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.createdAt,
    required this.category,
    required this.archived,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? 'Development',
      createdAt: json['created_at'] ?? '',
      archived: json['archived'] ?? false,
    );
  }
}

class EnrollmentPage extends StatefulWidget {
  final String userId;

  const EnrollmentPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _EnrollmentPageState createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Course> _courses = [];
  List<String> _categories = ['All', 'Development', 'Design', 'Business', 'Marketing'];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await _fetchCourses();
      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching courses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Course>> _fetchCourses() async {
  try {
    final response = await http.get(Uri.parse('http://bunn.helioho.st/courses.php?userId=${widget.userId}'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success']) {
        final courses = (data['courses'] as List)
            .map((c) => Course.fromJson(c))
            .toList();
        return courses;
      } else {
        throw Exception(data['message']);
      }
    } else {
      throw Exception('Failed to fetch courses');
    }
  } catch (e) {
    print('Error fetching courses: $e');
    rethrow;
  }
}

Future<void> _enrollInCourse(Course course) async {
  try {
    // Ensure userId and courseId are properly formatted
    if (widget.userId.isEmpty || course.id.isEmpty) {
      throw Exception('Invalid user or course ID');
    }

    final response = await http.post(
      Uri.parse('http://bunn.helioho.st/enroll.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'user_id': widget.userId,
        'course_id': course.id,
      }),
    );

    final data = jsonDecode(response.body);
    
    if (response.statusCode == 201 && data['success']) {
      _showEnrollmentSuccess(course);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnrolledCoursesPage(userId: widget.userId),
        ),
      );
    } else if (response.statusCode == 409) {
      throw Exception('Already enrolled in this course');
    } else {
      throw Exception(data['message'] ?? 'Failed to enroll in course');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  List<Course> _getFilteredCourses() {
    return _courses.where((course) {
      final matchesCategory = _selectedCategory == 'All' || course.category == _selectedCategory;
      final matchesSearch = course.title.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          course.description.toLowerCase().contains(_searchController.text.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }
  @override
  Widget build(BuildContext context) {
    final filteredCourses = _getFilteredCourses();

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                _buildCategoryFilter(),
              ],
            ),
          ),
          _isLoading ? _buildLoadingState() : _buildCourseGrid(filteredCourses),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
  return SliverAppBar(
    expandedHeight: 120,
    floating: true,
    pinned: true,
    backgroundColor: Color.fromARGB(255, 110, 227, 192),
    leading: IconButton(
      icon: Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () => Navigator.pop(context),
    ),
    actions: [
      // Add this new button
      TextButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnrolledCoursesPage(userId: widget.userId),
            ),
          );
        },
        icon: Icon(Icons.school, color: Colors.white),
        label: Text(
          'My Courses',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      SizedBox(width: 1), // Add some padding
    ],
    flexibleSpace: FlexibleSpaceBar(
      title: Text(
        'Course Enrollment',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 110, 227, 192),
              Color.fromARGB(255, 110, 227, 192).withOpacity(0.8),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search courses...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 40,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedCategory = category);
              },
              backgroundColor: Colors.grey[100],
              selectedColor: Color.fromARGB(255, 110, 227, 192).withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? Color.fromARGB(255, 110, 227, 192) : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return SliverFillRemaining(
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Color.fromARGB(255, 110, 227, 192),
          ),
        ),
      ),
    );
  }

 Widget _buildCourseGrid(List<Course> courses) {
  return SliverPadding(
    padding: EdgeInsets.all(16),
    sliver: SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final course = courses[index];
          if (course.archived) {
            return SizedBox.shrink(); // Skip rendering archived courses
          }
          return _CourseCard(
            course: course,
            onEnroll: () => _showEnrollmentDialog(course),
          );
        },
        childCount: courses.length,
      ),
    ),
  );
}

  void _showEnrollmentDialog(Course course) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Enroll in Course'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Would you like to enroll in:'),
          SizedBox(height: 8),
          Text(
            course.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _enrollInCourse(course);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color.fromARGB(255, 110, 227, 192),
          ),
          child: Text('Enroll'),
        ),
      ],
    ),
  );
}

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        SizedBox(width: 8),
        Text(text, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  void _showEnrollmentSuccess(Course course) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully enrolled in ${course.title}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onEnroll;

  const _CourseCard({
    Key? key,
    required this.course,
    required this.onEnroll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showCourseDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Image container
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 110, 227, 192).withOpacity(0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Icon(
                  Icons.school,
                  size: 48,
                  color: Color.fromARGB(255, 110, 227, 192),
                ),
              ),
            ),
            // Content container
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    // Description
                    Expanded(
                      child: Text(
                        course.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    // Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onEnroll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 110, 227, 192),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'View Details',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCourseDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                course.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                course.description,
                style: TextStyle(
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Content',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                course.content,
                style: TextStyle(
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Created',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                course.createdAt,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onEnroll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 110, 227, 192),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Enroll in Course',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildDetailSection({
  required String title,
  required List<Widget> children,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      SizedBox(height: 12),
      ...children,
    ],
  );
}

Widget _buildDetailRow(IconData icon, String label, String value) {
  return Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
