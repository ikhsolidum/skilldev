import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:skilldev_mobapp/home/enroll.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/foundation.dart' show kReleaseMode;

class CustomHttpClient {
  static HttpClient createHttpClient() {
    HttpClient client = HttpClient()
      ..connectionTimeout = Duration(seconds: 30)
      ..idleTimeout = Duration(seconds: 30);

    client.badCertificateCallback = ((X509Certificate cert, String host, int port) {
      // In debug mode, allow all certificates
      if (kDebugMode) {
        print('Untrusted certificate: Host=$host, Port=$port');
        print('Certificate Subject: ${cert.subject}');
        print('Certificate Issuer: ${cert.issuer}');
        return true;
      }

      // In release mode, perform stricter validation
      return host == 'bunn.helioho.st';
    });

    return client;
  }

  static http.Client getClient() {
    return IOClient(createHttpClient());
  }
}

class UserCertificate {
  final int id;
  final int certificateId;
  final String imagePath;
  final String description;
  final String assignedAt;

  UserCertificate({
    required this.id,
    required this.certificateId,
    required this.imagePath,
    required this.description,
    required this.assignedAt,
  });
}

class CertificatesPage extends StatefulWidget {
  final String userId;
  final String username;

  const CertificatesPage({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  _CertificatesPageState createState() => _CertificatesPageState();
}

class _CertificatesPageState extends State<CertificatesPage> {
  List<UserCertificate>? _certificates;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    setState(() {
      _isLoading = true;
    });

    final httpClient = CustomHttpClient.getClient();

    try {
      final response = await httpClient.get(
        Uri.parse('http://bunn.helioho.st/certificates.php?userId=${widget.userId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final certificates = (data['certificates'] as List)
              .map((certificate) => UserCertificate(
                    id: int.parse(certificate['id'].toString()),
                    certificateId: int.parse(certificate['certificate_id'].toString()),
                    imagePath: certificate['image_path'] ?? '',
                    description: certificate['description'] ?? '',
                    assignedAt: certificate['assigned_at'] ?? '',
                  ))
              .toList();
          setState(() {
            _certificates = certificates;
            _isLoading = false;
          });
        } else {
          setState(() {
            _certificates = [];
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No certificates found')),
          );
        }
      } else {
        setState(() {
          _certificates = [];
          _isLoading = false;
        });
        print('Error fetching certificates: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching certificates: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _certificates = [];
        _isLoading = false;
      });
      print('Exception in fetching certificates: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  // New method to show full-screen certificate image
  void _showCertificateImage(UserCertificate certificate) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              certificate.description,
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                certificate.imagePath,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.fromARGB(255, 110, 227, 192),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.error, color: Colors.red, size: 50),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCertificatesList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _certificates!.length,
      itemBuilder: (context, index) {
        final certificate = _certificates![index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => _showCertificateImage(certificate),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(certificate.imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          certificate.description,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Assigned: ${certificate.assignedAt}',
                          style: TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Certificates',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: Color.fromARGB(255, 110, 227, 192),
        onRefresh: _loadCertificates,
        child: _isLoading
            ? _buildLoadingState()
            : _certificates == null || _certificates!.isEmpty
                ? _buildEmptyState()
                : _buildCertificatesList(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          Color.fromARGB(255, 110, 227, 192),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 110, 227, 192).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_outlined,
                  size: 80,
                  color: Color.fromARGB(255, 110, 227, 192),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'No Certificates Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Start your learning journey and earn your first certificate!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EnrollmentPage(userId: widget.userId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 110, 227, 192),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Browse Courses',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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