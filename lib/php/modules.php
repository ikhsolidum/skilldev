<?php
// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);
error_log("Modules endpoint hit");

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
$response = array('success' => false, 'message' => '', 'modules' => array());

// Get courseId and userId from the request and validate them
$courseId = isset($_GET['course_id']) ? trim($_GET['course_id']) : null;
$userId = isset($_GET['user_id']) ? trim($_GET['user_id']) : null;

// Validate course_id
if (!$courseId) {
    $response['message'] = 'Course ID is required';
    http_response_code(400);
    echo json_encode($response);
    exit();
}

// Validate user_id
if (!$userId) {
    $response['message'] = 'User ID is required';
    http_response_code(400);
    echo json_encode($response);
    exit();
}

// Ensure course_id and user_id are numeric
if (!is_numeric($courseId) || !is_numeric($userId)) {
    $response['message'] = 'Invalid ID format';
    http_response_code(400);
    echo json_encode($response);
    exit();
}

// Convert to integer
$courseId = intval($courseId);
$userId = intval($userId);

// Create database connection
$database = new Database();
$db = $database->getConnection();

if ($db) {
    try {
        // Log the query parameters
        error_log("Querying modules for course_id: " . $courseId . " and user_id: " . $userId);

        // Modified query to remove feedback column
        $query = "SELECT 
                    c.id, 
                    c.course_id, 
                    c.title, 
                    c.content,
                    CASE 
                        WHEN mc.id IS NOT NULL THEN '1' 
                        ELSE '0' 
                    END as is_completed
                FROM chapters c
                LEFT JOIN module_completion mc ON c.id = mc.chapter_id 
                    AND mc.user_id = :user_id
                WHERE c.course_id = :course_id 
                ORDER BY c.id ASC";

        $stmt = $db->prepare($query);
        $stmt->bindValue(':course_id', $courseId, PDO::PARAM_INT);
        $stmt->bindValue(':user_id', $userId, PDO::PARAM_INT);
        
        if ($stmt->execute()) {
            $modules = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            if ($modules && count($modules) > 0) {
                $response['success'] = true;
                $response['modules'] = $modules;
                http_response_code(200);
            } else {
                $response['message'] = 'No modules found for this course';
                http_response_code(404);
            }
        } else {
            $error = $stmt->errorInfo();
            error_log("SQL Error: " . print_r($error, true));
            throw new PDOException("Query execution failed: " . $error[2]);
        }
    } catch (PDOException $e) {
        error_log("Database error in modules.php: " . $e->getMessage());
        $response['message'] = 'Database error: ' . $e->getMessage();
        http_response_code(500);
    }
} else {
    error_log("Failed to connect to database in modules.php");
    $response['message'] = 'Unable to connect to database';
    http_response_code(500);
}

// Send response
echo json_encode($response);
?>