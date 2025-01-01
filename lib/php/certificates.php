<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
error_log("Certificates endpoint hit");

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

require_once 'mobile-connect.php';

$response = array('success' => false, 'message' => '', 'certificates' => array());

$userId = isset($_GET['userId']) ? $_GET['userId'] : null;

if (!$userId) {
    $response['message'] = 'User ID is required';
    http_response_code(400);
    echo json_encode($response);
    exit();
}

$database = new Database();
$db = $database->getConnection();

if ($db) {
    try {
        $query = "SELECT 
                uc.id, 
                c.id AS certificate_id,
                c.image_path AS image_path,
                c.description,
                DATE_FORMAT(uc.assigned_at, '%Y-%m-%d') as assigned_at
            FROM user_certificates uc
            JOIN certifications c ON uc.certificate_id = c.id
            WHERE uc.user_id = :userId";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':userId', $userId);
        $stmt->execute();

        $certificates = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if ($certificates) {
            // Modify image paths to be full URLs
            $certificates = array_map(function($cert) {
                $cert['image_path'] = 'https://bunn.helioho.st/' . $cert['image_path'];
                return $cert;
            }, $certificates);

            $response['success'] = true;
            $response['certificates'] = $certificates;
            http_response_code(200);
        } else {
            $response['message'] = 'No certificates found for the user';
            http_response_code(404);
        }
    } catch (PDOException $e) {
        $response['message'] = 'Database error: ' . $e->getMessage();
        error_log("Database error: " . $e->getMessage());
        http_response_code(500);
    } catch (Exception $e) {
        $response['message'] = 'Error: ' . $e->getMessage();
        error_log("Error: " . $e->getMessage());
        http_response_code(500);
    }
} else {
    $response['message'] = 'Unable to connect to database';
    http_response_code(500);
}

echo json_encode($response);
?>