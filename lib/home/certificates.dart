import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:open_file/open_file.dart';
import 'package:skilldev_mobapp/home/enroll.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

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
  final String uploadedAt; 

  UserCertificate({
    required this.id,
    required this.certificateId,
    required this.imagePath,
    required this.description,
    required this.assignedAt,
    required this.uploadedAt,
  });

  factory UserCertificate.fromJson(Map<String, dynamic> json) {
    print('Processing certificate JSON: $json'); // Debug print
    return UserCertificate(
      id: int.parse(json['id'].toString()),
      certificateId: int.parse(json['certificate_id'].toString()),
      imagePath: json['image_path'] ?? '',
      description: json['description'] ?? '',
      assignedAt: json['assigned_at'] ?? '',
      uploadedAt: json['uploaded_at'] ?? '',
    );
}
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

  // Error handling helper method
void _handleError(String message) {
  if (!mounted) return;
  
  setState(() {
    _certificates = [];
    _isLoading = false;
  });
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 3),
    ),
  );
}

Future<bool> _requestStoragePermission() async {
  if (Platform.isAndroid) {
    if (await Permission.storage.isGranted) {
      return true;
    }
    
    // For Android 13 and above
    if (await Permission.photos.isGranted) {
      return true;
    }
    
    // Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.photos,
    ].request();
    
    return statuses[Permission.storage]!.isGranted || 
           statuses[Permission.photos]!.isGranted;
  }
  return true; 
}


Widget _buildCertificatesList() {
  return ListView.builder(
    padding: EdgeInsets.all(16),
    itemCount: _certificates?.length ?? 0,
    itemBuilder: (context, index) {
      final certificate = _certificates![index];
      return _buildCertificateCard(certificate);
    },
  );
}

 Future<void> _downloadCertificate(UserCertificate certificate) async {
  try {
    // First check and request permissions
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage permission is required to download certificates'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

    // Show loading indicator
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(width: 16),
            Text('Downloading certificate...'),
          ],
        ),
        duration: Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Create custom http client with proper timeout and certificate handling
    final httpClient = CustomHttpClient.getClient();

    // Download the image
    final response = await httpClient.get(
      Uri.parse(certificate.imagePath),
      headers: {
        'Accept': '*/*',
        'Cache-Control': 'no-cache',
      },
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Download timed out');
      },
    );

    if (response.statusCode == 200) {
      // Get the app's documents directory for saving
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'certificate_${certificate.id}_$timestamp.jpg';
      final filePath = '${appDir.path}/$fileName';
      
      // Save to file
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Try to save to gallery using gallery_saver
      bool? savedToGallery = false;
      try {
        savedToGallery = await GallerySaver.saveImage(filePath, albumName: 'Certificates');
      } catch (e) {
        print('Gallery saver failed: $e');
        // If gallery_saver fails, we still have the file saved in app directory
        savedToGallery = true; // Consider it saved since we have it in app directory
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      if (savedToGallery == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Certificate saved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () async {
                // Try to open the file using the default viewer
                try {
                  await OpenFile.open(filePath);
                } catch (e) {
                  print('Failed to open file: $e');
                }
              },
            ),
          ),
        );
      } else {
        throw Exception('Failed to save certificate');
      }
    } else {
      throw HttpException(
        'Server returned ${response.statusCode}: ${response.reasonPhrase}'
      );
    }
  } catch (e) {
    print('Download error: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to download certificate: ${e.toString()}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

  Future<void> _loadCertificates() async {
  if (!mounted) return;
  
  setState(() {
    _isLoading = true;
  });

  final httpClient = CustomHttpClient.getClient();

  try {
    final response = await httpClient.get(
      Uri.parse('http://bunn.helioho.st/certificates.php?userId=${widget.userId}'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 30));

    if (!mounted) return;

    print('Response status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      String cleanResponse = response.body.trim();
      // Remove any potential HTML or whitespace before the JSON
      if (cleanResponse.contains('{')) {
        cleanResponse = cleanResponse.substring(cleanResponse.indexOf('{'));
      }

      try {
        final data = json.decode(cleanResponse) as Map<String, dynamic>;
        
        if (data['success'] == true) {
          List<UserCertificate> certificates = [];
          
          if (data['certificates'] != null && data['certificates'] is List) {
            certificates = (data['certificates'] as List)
                .map((cert) => UserCertificate.fromJson(cert))
                .toList();
            
            // Sort certificates by assigned date, most recent first
            certificates.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
          }
          
          setState(() {
            _certificates = certificates;
            _isLoading = false;
          });
        } else {
          _handleError(data['message'] ?? 'No certificates available');
        }
      } catch (e) {
        print('JSON parsing error: $e');
        _handleError('Error processing response: $e');
      }
    } else {
      _handleError('Server returned status code: ${response.statusCode}');
    }
  } on TimeoutException {
    _handleError('Connection timeout. Please check your internet connection.');
  } catch (e) {
    print('Error loading certificates: $e');
    _handleError('Error loading certificates. Please try again.');
  }
}

 void _showCertificateImage(UserCertificate certificate) {
  final imageUrl = Uri.parse(certificate.imagePath.trim()).toString();
  print('Loading image from URL: $imageUrl');
  
  final imageProvider = NetworkImage(
    imageUrl,
    headers: {
      'Accept': '*/*',
      'Cache-Control': 'no-cache',
    },
  );

  precacheImage(imageProvider, context).catchError((error) {
    print('Precache error: $error');
  });

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
          actions: [
            IconButton(
              icon: Icon(Icons.download, color: Colors.white),
              onPressed: () => _downloadCertificate(certificate),
              tooltip: 'Download Certificate',
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  maxScale: 5.0,
                  child: Image(
                    image: imageProvider,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / 
                                  loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color.fromARGB(255, 110, 227, 192),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading image...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Image error: $error');
                      print('Attempted URL: $imageUrl');
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.red, size: 64),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              error.toString(),
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showCertificateImage(certificate);
                            },
                            child: Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 110, 227, 192),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildCertificateCard(UserCertificate certificate) {
  final imageUrl = certificate.imagePath.trim();

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
            Hero(
              tag: 'certificate_${certificate.id}',
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    headers: {
                      'Accept': '*/*',
                      'Cache-Control': 'no-cache',
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.fromARGB(255, 110, 227, 192),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Thumbnail error: $error');
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey[400],
                          size: 32,
                        ),
                      );
                    },
                  ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Awarded: ${_formatDate(certificate.assignedAt)}',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.download_outlined),
                  onPressed: () => _downloadCertificate(certificate),
                  tooltip: 'Download Certificate',
                ),
                IconButton(
                  icon: Icon(Icons.share_outlined),
                  onPressed: () => _shareCertificate(certificate),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper method to format dates
String _formatDate(String dateStr) {
  try {
    final date = DateTime.parse(dateStr);
    return '${date.month}/${date.day}/${date.year}';
  } catch (e) {
    return dateStr;
  }
}

// Share certificate method
void _shareCertificate(UserCertificate certificate) {
  // Implement sharing functionality
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Sharing coming soon!'),
      behavior: SnackBarBehavior.floating,
    ),
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