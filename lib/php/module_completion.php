<?php
// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);
error_log("Module completion endpoint hit");

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
$response = array('success' => false, 'message' => '', 'completed' => false);

// Get posted data
$data = json_decode(file_get_contents("php://input"));

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!empty($data->user_id) && !empty($data->module_id)) {
        try {
            // Create database connection
            $database = new Database();
            $db = $database->getConnection();

            if (!$db) {
                throw new Exception("Database connection failed");
            }

            // Convert values to appropriate types
            $userId = intval($data->user_id);
            $moduleId = intval($data->module_id);
           

            // Check if module completion record exists
            $check_query = "SELECT id FROM module_completion 
            WHERE user_id = :userId AND chapter_id = :moduleId";
            $check_stmt = $db->prepare($check_query);
            $check_stmt->bindValue(':userId', $userId, PDO::PARAM_INT);
            $check_stmt->bindValue(':moduleId', $moduleId, PDO::PARAM_INT);

            if ($check_stmt->rowCount() > 0) {
                // Delete existing record (toggle off)
                $delete_query = "DELETE FROM module_completion 
                               WHERE user_id = ? AND chapter_id = ?";
                $delete_stmt = $db->prepare($delete_query);
                
                if ($delete_stmt->execute([$userId, $moduleId])) {
                    $response = array(
                        'success' => true,
                        'completed' => false,
                        'message' => 'Module completion status removed'
                    );
                }
            } else {
                // Insert new completion record (toggle on)
                $insert_query = "INSERT INTO module_completion (user_id, chapter_id) 
                               VALUES (?, ?)";
                $insert_stmt = $db->prepare($insert_query);
                
                if ($insert_stmt->execute([$userId, $moduleId])) {
                    $response = array(
                        'success' => true,
                        'completed' => true,
                        'message' => 'Module marked as completed'
                    );
                }
            }
        } catch (Exception $e) {
            error_log("Error in module_completion.php: " . $e->getMessage());
            $response['message'] = 'Error processing request: ' . $e->getMessage();
            http_response_code(500);
        }
    } else {
        $response['message'] = 'Missing required parameters';
        http_response_code(400);
    }
} else {
    $response['message'] = 'Invalid request method';
    http_response_code(405);
}

// Send response
echo json_encode($response);
?>