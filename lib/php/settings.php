<?php
// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);
error_log("Settings endpoint hit");

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
$response = array('success' => false, 'message' => '', 'debug' => array());

// Get JSON data
$rawData = file_get_contents("php://input");
$data = json_decode($rawData, true) ?? array();

// Extract userId from the request data
$userId = isset($data['userId']) ? $data['userId'] : null;

error_log("Received data: " . print_r($data, true));

// Extract data from JSON
$notificationsEnabled = isset($data['notificationsEnabled']) ? $data['notificationsEnabled'] : true;
$emailNotificationsEnabled = isset($data['emailNotificationsEnabled']) ? $data['emailNotificationsEnabled'] : true;
$darkModeEnabled = isset($data['darkModeEnabled']) ? $data['darkModeEnabled'] : false;
$selectedLanguage = isset($data['selectedLanguage']) ? $data['selectedLanguage'] : 'English';
$textSize = isset($data['textSize']) ? $data['textSize'] : 1.0;

// Check if required fields are present
if (
    empty($userId) ||
    $notificationsEnabled === null ||
    $emailNotificationsEnabled === null ||
    $darkModeEnabled === null ||
    empty($selectedLanguage) ||
    $textSize === null
) {
    $response['message'] = 'Incomplete data provided';
    $response['debug'] = [
        'userId' => $userId,
        'notificationsEnabled' => $notificationsEnabled,
        'emailNotificationsEnabled' => $emailNotificationsEnabled,
        'darkModeEnabled' => $darkModeEnabled,
        'selectedLanguage' => $selectedLanguage,
        'textSize' => $textSize
    ];
    http_response_code(400);
} else {
    // Create database connection
    $database = new Database();
    $db = $database->getConnection();

    if ($db) {
        try {
            // First check if settings already exist for the user
            $checkQuery = "SELECT COUNT(*) FROM settings WHERE user_id = :userId";
            $checkStmt = $db->prepare($checkQuery);
            $checkStmt->bindParam(':userId', $userId);
            $checkStmt->execute();
            
            if ($checkStmt->fetchColumn() > 0) {
                // Update existing settings
                $updateQuery = "UPDATE settings
                                SET notificationsEnabled = :notificationsEnabled,
                                    emailNotificationsEnabled = :emailNotificationsEnabled,
                                    darkModeEnabled = :darkModeEnabled,
                                    selectedLanguage = :selectedLanguage,
                                    textSize = :textSize
                                WHERE user_id = :userId";
                
                $updateStmt = $db->prepare($updateQuery);
                $updateStmt->bindParam(':notificationsEnabled', $notificationsEnabled);
                $updateStmt->bindParam(':emailNotificationsEnabled', $emailNotificationsEnabled);
                $updateStmt->bindParam(':darkModeEnabled', $darkModeEnabled);
                $updateStmt->bindParam(':selectedLanguage', $selectedLanguage);
                $updateStmt->bindParam(':textSize', $textSize);
                $updateStmt->bindParam(':userId', $userId);
                
                if ($updateStmt->execute()) {
                    $response['success'] = true;
                    $response['message'] = 'Settings updated successfully';
                    http_response_code(200);
                } else {
                    $response['message'] = 'Unable to update settings';
                    $response['debug']['sql_error'] = $updateStmt->errorInfo();
                    http_response_code(500);
                }
            } else {
                // Insert new settings
                $insertQuery = "INSERT INTO settings (user_id, notificationsEnabled, emailNotificationsEnabled, darkModeEnabled, selectedLanguage, textSize)
                                VALUES (:userId, :notificationsEnabled, :emailNotificationsEnabled, :darkModeEnabled, :selectedLanguage, :textSize)";
                
                $insertStmt = $db->prepare($insertQuery);
                $insertStmt->bindParam(':userId', $userId);
                $insertStmt->bindParam(':notificationsEnabled', $notificationsEnabled);
                $insertStmt->bindParam(':emailNotificationsEnabled', $emailNotificationsEnabled);
                $insertStmt->bindParam(':darkModeEnabled', $darkModeEnabled);
                $insertStmt->bindParam(':selectedLanguage', $selectedLanguage);
                $insertStmt->bindParam(':textSize', $textSize);
                
                if ($insertStmt->execute()) {
                    $response['success'] = true;
                    $response['message'] = 'Settings saved successfully';
                    http_response_code(201);
                } else {
                    $response['message'] = 'Unable to save settings';
                    $response['debug']['sql_error'] = $insertStmt->errorInfo();
                    http_response_code(500);
                }
            }
        } catch (PDOException $e) {
            $response['message'] = 'Database error: ' . $e->getMessage();
            $response['debug']['exception'] = $e->getMessage();
            error_log("Database error: " . $e->getMessage());
            http_response_code(500);
        }
    } else {
        $response['message'] = 'Unable to connect to database';
        $response['debug']['connection'] = 'Database connection failed';
        http_response_code(500);
    }
}

// Send response
echo json_encode($response);
error_log("Response sent: " . json_encode($response));
?>
