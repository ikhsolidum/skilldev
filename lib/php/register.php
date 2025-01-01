<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
ob_start();  // Start output buffering

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

// CORS headers
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

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header("HTTP/1.1 200 OK");
    exit();
}

// Initialize response array
$response = array('success' => false, 'message' => '', 'debug' => array());

try {
    // Include database connection
    require_once 'mobile-connect.php';

    // Log all received data for debugging
    $response['debug']['_POST'] = $_POST;
    $response['debug']['_FILES'] = $_FILES;

    // Validate required fields before processing files
    $username = $_POST['username'] ?? null;
    $email = $_POST['email'] ?? null;
    $password = $_POST['password'] ?? null;

    // Validate required fields
    if (empty($username) || empty($email) || empty($password)) {
        $response['message'] = 'Incomplete data provided';
        $response['debug']['missing_fields'] = [
            'username' => $username ? 'provided' : 'missing',
            'email' => $email ? 'provided' : 'missing',
            'password' => $password ? 'provided' : 'missing'
        ];
        http_response_code(400);
        throw new Exception('Missing required text fields');
    }

    // Function to handle file upload with multiple possible keys
    function uploadFile($possibleKeys, $uploadDir) {
        foreach ($possibleKeys as $key) {
            if (isset($_FILES[$key]) && $_FILES[$key]['error'] === UPLOAD_ERR_OK) {
                $fileName = $_FILES[$key]['name'];
                $tmpName = $_FILES[$key]['tmp_name'];
                $destination = $uploadDir . uniqid() . '_' . $fileName;

                if (move_uploaded_file($tmpName, $destination)) {
                    return $destination;
                }
            }
        }
        return null;
    }

    // Handle ID proof image upload
    $id_proof_image = uploadFile([
        'id_proof_file', 
        'id_proof', 
        'idProofFile', 
        'idProof'
    ], 'cap_admin/uploads/');

    if (empty($id_proof_image)) {
        $response['debug']['id_proof_upload'] = 'Failed';
        throw new Exception('ID proof file not uploaded');
    }

    // Handle proof of clearance image upload
    $proof_clearance_image = uploadFile([
        'proof_clearance_file', 
        'proof_clearance', 
        'proofClearanceFile', 
        'clearanceFile'
    ], 'cap_admin/uploads/');

    if (empty($proof_clearance_image)) {
        $response['debug']['proof_clearance_upload'] = 'Failed';
        throw new Exception('Proof of clearance file not uploaded');
    }

    // Handle profile image upload
    $profileImage = uploadFile([
        'profileImage', 
        'profile_image', 
        'profile', 
        'image'
    ], 'cap_admin/uploads/');

    if (empty($profileImage)) {
        $response['debug']['profile_image_upload'] = 'Failed';
        throw new Exception('Profile image not uploaded');
    }

    // Create database connection
    $database = new Database();
    $db = $database->getConnection();

    // Check if email already exists
    $checkQuery = "SELECT COUNT(*) FROM users WHERE email = :email";
    $checkStmt = $db->prepare($checkQuery);
    $checkStmt->bindParam(':email', $email);
    $checkStmt->execute();
    
    if ($checkStmt->fetchColumn() > 0) {
        $response['message'] = 'Email already registered';
        http_response_code(409);
        throw new Exception('Email already in use');
    }

    // Prepare insert query (modified to use image paths for all previously text fields)
    $query = "INSERT INTO users (username, email, password, id_proof, id_proof_path, proof_clearance, proof_clearance_path, profileImage, profileImage_path) 
              VALUES (:username, :email, :password, :id_proof_filename, :id_proof_path, :proof_clearance_filename, :proof_clearance_path, :profileImage, :profileImage_path)";
    
    // Prepare statement
    $stmt = $db->prepare($query);

    // Sanitize and hash password
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);

    // Extract filenames
    $id_proof_filename = basename($id_proof_image);
    $proof_clearance_filename = basename($proof_clearance_image);
    $profileName = basename($profileImage);

    // Bind parameters
    $stmt->bindParam(':username', $username);
    $stmt->bindParam(':email', $email);
    $stmt->bindParam(':password', $hashedPassword);
    $stmt->bindParam(':id_proof_filename', $id_proof_filename);
    $stmt->bindParam(':id_proof_path', $id_proof_image);
    $stmt->bindParam(':proof_clearance_filename', $proof_clearance_filename);
    $stmt->bindParam(':proof_clearance_path', $proof_clearance_image);
    $stmt->bindParam(':profileImage', $profileName);
    $stmt->bindParam(':profileImage_path', $profileImage);

    // Execute registration
    if (!$stmt->execute()) {
        throw new Exception('Unable to register user');
    }

    // Successful registration
    $response['success'] = true;
    $response['message'] = 'User registered successfully';
    $response['username'] = $username;
    $response['email'] = $email;
    http_response_code(201);

} catch (Exception $e) {
    // Catch any exceptions
    $response['message'] = $response['message'] ?: $e->getMessage();
    error_log("Registration error: " . $e->getMessage());
    http_response_code($response['message'] === 'Email already registered' ? 409 : 500);
}

// Ensure a response is always sent
header('Content-Type: application/json');
echo json_encode($response);
ob_end_clean();  // Clear output buffer
header('Content-Type: application/json');
echo json_encode($response);
exit;