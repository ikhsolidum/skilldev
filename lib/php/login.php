<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);
ini_set('error_log', 'login_error.log');
error_log("Login endpoint hit - Starting execution");

// CORS headers
$origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : '';
$allowed_origins = array(
    'http://localhost:3000',
    'http://localhost',
    'http://localhost:56740',
    'capacitor://localhost',
    'http://localhost:8080',
    'http://127.0.0.1',
    'http://127.0.0.1:8080'
);

if (in_array($origin, $allowed_origins)) {
    header("Access-Control-Allow-Origin: $origin");
} else {
    header("Access-Control-Allow-Origin: *");
}

header("Access-Control-Allow-Credentials: true");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Max-Age: 3600");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header("HTTP/1.1 200 OK");
    exit();
}

try {
    error_log("Attempting to require mobile-connect.php");
    require_once 'mobile-connect.php';
    error_log("Successfully included mobile-connect.php");
} catch (Exception $e) {
    error_log("Error including mobile-connect.php: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Configuration error']);
    exit();
}

// Log raw input data
$rawData = file_get_contents("php://input");
error_log("Raw input data: " . $rawData);

// Decode JSON and check for errors
$data = json_decode($rawData);
if (json_last_error() !== JSON_ERROR_NONE) {
    error_log("JSON decode error: " . json_last_error_msg());
}

$response = array('success' => false, 'message' => '', 'username' => '', 'user_id' => null);  // Initialize user_id in response

if (!isset($data) || !is_object($data)) {
    error_log("Invalid JSON data received");
    $response['message'] = 'Invalid JSON data received';
    http_response_code(400);
} else if (empty($data->email) || empty($data->password)) {
    error_log("Missing email or password");
    $response['message'] = 'Email and password are required';
    http_response_code(400);
} else {
    error_log("Attempting database connection");
    $database = new Database();
    try {
        $db = $database->getConnection();
        error_log("Database connection successful");

        if ($db) {
            try {
                $query = "SELECT user_id, email, password, username, status FROM users WHERE email = :email";
                error_log("Preparing query: " . $query);
                
                $stmt = $db->prepare($query);
                $stmt->bindParam(':email', $data->email);
                error_log("Executing query for email: " . $data->email);
                
                $stmt->execute();
                error_log("Query executed successfully");

                if ($user = $stmt->fetch(PDO::FETCH_ASSOC)) {
                    error_log("User found, checking status and verifying password");
                    
                    // Check account status first
                    if ($user['status'] === 'disabled') {
                        error_log("Account is disabled for email: " . $data->email);
                        $response['message'] = 'Your account has been suspended. Please contact support.';
                        http_response_code(403);  // Using 403 Forbidden for suspended accounts
                    } else if (password_verify($data->password, $user['password'])) {
                        $response['success'] = true;
                        $response['message'] = 'Login successful';
                        $response['user_id'] = strval($user['user_id']);  // Convert to string explicitly
                        $response['username'] = $user['username'];
                        error_log("Password verified successfully. User ID: " . $response['user_id']);
                        http_response_code(200);
                    } else {
                        error_log("Invalid password for user");
                        $response['message'] = 'Invalid password';
                        http_response_code(401);
                    }
                } else {
                    error_log("No user found with email: " . $data->email);
                    $response['message'] = 'User not found';
                    http_response_code(401);
                }
            } catch (PDOException $e) {
                error_log("Database query error: " . $e->getMessage());
                $response['message'] = 'Database error: ' . $e->getMessage();
                http_response_code(500);
            }
        } else {
            error_log("Database connection failed");
            $response['message'] = 'Database connection failed';
            http_response_code(500);
        }
    } catch (Exception $e) {
        error_log("Database connection error: " . $e->getMessage());
        $response['message'] = 'Database connection error';
        http_response_code(500);
    }
}

error_log("Final response: " . json_encode($response));
echo json_encode($response);