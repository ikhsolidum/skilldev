<?php
// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);
error_log("Notifications endpoint hit");

// Get the requesting origin
$origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : '';

// List of allowed origins
$allowed_origins = array(
    'http://localhost:3000',
    'http://localhost',
    'http://localhost:56740',
    'capacitor://localhost',
    'http://localhost:8080',
    'http://127.0.0.1',
    'http://127.0.0.1:8080'
);

// Check if the origin is allowed
if (in_array($origin, $allowed_origins)) {
    header("Access-Control-Allow-Origin: $origin");
} else {
    header("Access-Control-Allow-Origin: *");
}

// Required CORS headers
header("Access-Control-Allow-Credentials: true");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Max-Age: 3600");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header("HTTP/1.1 200 OK");
    exit();
}

// Include database connection
require_once 'mobile-connect.php';

// Initialize response array
$response = array('success' => false, 'message' => '', 'notifications' => array());

// Create database connection
$database = new Database();
$db = $database->getConnection();

if ($db) {
    try {
        // Retrieve announcements
        $query = "SELECT id, title, message, created_at 
                 FROM announcements 
                 ORDER BY created_at DESC";
        
        $stmt = $db->prepare($query);
        
        if ($stmt->execute()) {
            $announcements = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            if ($announcements && count($announcements) > 0) {
                $response['success'] = true;
                $response['notifications'] = $announcements;
                http_response_code(200);
            } else {
                $response['message'] = 'No announcements found';
                $response['notifications'] = [];
                http_response_code(200); // Still return 200 for empty results
            }
        } else {
            $error = $stmt->errorInfo();
            error_log("SQL Error: " . print_r($error, true));
            throw new PDOException("Query execution failed: " . $error[2]);
        }
    } catch (PDOException $e) {
        error_log("Database error in notifications.php: " . $e->getMessage());
        $response['message'] = 'Database error: ' . $e->getMessage();
        http_response_code(500);
    }
} else {
    error_log("Failed to connect to database in notifications.php");
    $response['message'] = 'Unable to connect to database';
    http_response_code(500);
}

// Send response
echo json_encode($response);
?>