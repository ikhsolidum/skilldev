<?php
// enroll.php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'mobile-connect.php';

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, GET");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

$database = new Database();
$db = $database->getConnection();
$response = array('success' => false, 'message' => '');

// Enroll in a course
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"));
    
    if (!isset($data->user_id) || !isset($data->course_id)) {
        $response['message'] = 'Missing required fields';
        http_response_code(400);
    } else {
        try {
            $query = "INSERT INTO enrollments (user_id, course_id) VALUES (:user_id, :course_id)";
            $stmt = $db->prepare($query);
            $stmt->bindParam(':user_id', $data->user_id);
            $stmt->bindParam(':course_id', $data->course_id);
            
            if ($stmt->execute()) {
                $response['success'] = true;
                $response['message'] = 'Successfully enrolled';
                http_response_code(201);
            } else {
                $response['message'] = 'Failed to enroll';
                http_response_code(500);
            }
        } catch (PDOException $e) {
            if ($e->getCode() == 23000) { // Duplicate entry error
                $response['message'] = 'Already enrolled in this course';
                http_response_code(409);
            } else {
                $response['message'] = 'Database error: ' . $e->getMessage();
                http_response_code(500);
            }
        }
    }
}

// Get enrolled courses
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $user_id = isset($_GET['user_id']) ? $_GET['user_id'] : null;
    
    if (!$user_id) {
        $response['message'] = 'User ID is required';
        http_response_code(400);
    } else {
        try {
            $query = "SELECT lm.*, e.enrolled_at, e.status 
            FROM learning_modules lm 
            INNER JOIN enrollments e ON lm.id = e.course_id 
            WHERE e.user_id = :user_id AND (lm.archived = 0 OR lm.archived IS NULL)";
            $stmt = $db->prepare($query);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->execute();
            
            $courses = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            if ($courses) {
                $response['success'] = true;
                $response['courses'] = $courses;
                http_response_code(200);
            } else {
                $response['message'] = 'No enrolled courses found';
                http_response_code(404);
            }
        } catch (PDOException $e) {
            $response['message'] = 'Database error: ' . $e->getMessage();
            http_response_code(500);
        }
    }
}

echo json_encode($response);
?>