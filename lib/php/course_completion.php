<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
error_log("Course completion endpoint hit");

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

$response = array(
    'success' => false,
    'message' => '',
    'is_completed' => false,
    'completed_modules' => 0,
    'total_modules' => 0,
    'completed_at' => null
);

try {
    $database = new Database();
    $db = $database->getConnection();
    
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $data = json_decode(file_get_contents("php://input"));
        
        // Validate input data
        $user_id = filter_var($data->user_id ?? null, FILTER_VALIDATE_INT);
        $course_id = filter_var($data->course_id ?? null, FILTER_VALIDATE_INT);
        $action = $data->action ?? null;

        if ($user_id === false || $course_id === false || $user_id === null || $course_id === null) {
            throw new Exception('Invalid user_id or course_id');
        }

        // If action is complete_course, force insert completion record
        if ($action === 'complete_course') {
            $current_time = date('Y-m-d H:i:s');
            
            // First, check if record already exists
            $check_query = "SELECT completed_at FROM course_completion 
                          WHERE user_id = :user_id AND course_id = :course_id";
            $check_stmt = $db->prepare($check_query);
            $check_stmt->bindValue(':user_id', $user_id, PDO::PARAM_INT);
            $check_stmt->bindValue(':course_id', $course_id, PDO::PARAM_INT);
            $check_stmt->execute();
            
            if (!$check_stmt->fetch()) {
                // Insert new completion record
                $insert_query = "INSERT INTO course_completion (user_id, course_id, completed_at) 
                               VALUES (:user_id, :course_id, :completed_at)";
                $insert_stmt = $db->prepare($insert_query);
                $insert_stmt->bindValue(':user_id', $user_id, PDO::PARAM_INT);
                $insert_stmt->bindValue(':course_id', $course_id, PDO::PARAM_INT);
                $insert_stmt->bindValue(':completed_at', $current_time);
                
                if (!$insert_stmt->execute()) {
                    throw new Exception('Failed to insert course completion record');
                }
            }
            
            $response['success'] = true;
            $response['is_completed'] = true;
            $response['completed_at'] = $current_time;
            $response['message'] = 'Course marked as completed successfully';
        } else {
            // Original completion check logic
            $check_query = "SELECT 
            c.total_modules,
            COALESCE(mc.completed_modules, 0) as completed_modules,
            cc.completed_at
            FROM (
                SELECT :courseId as course_id, COUNT(*) as total_modules 
                FROM chapters 
                WHERE course_id = :courseId
            ) c
            LEFT JOIN (
                SELECT course_id, COUNT(DISTINCT mc.chapter_id) as completed_modules
                FROM module_completion mc
                INNER JOIN chapters ch ON mc.chapter_id = ch.id
                WHERE ch.course_id = :courseId AND mc.user_id = :userId
                GROUP BY course_id
            ) mc ON mc.course_id = c.course_id
            LEFT JOIN course_completion cc 
                ON cc.course_id = c.course_id AND cc.user_id = :userId";

        $check_stmt = $db->prepare($check_query);
        $check_stmt->bindValue(':courseId', $course_id, PDO::PARAM_INT);
        $check_stmt->bindValue(':userId', $user_id, PDO::PARAM_INT);
            $check_stmt->execute();
            
            $result = $check_stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($result) {
                $response['success'] = true;
                $response['total_modules'] = (int)$result['total_modules'];
                $response['completed_modules'] = (int)$result['completed_modules'];
                $response['is_completed'] = !empty($result['completed_at']);
                $response['completed_at'] = $result['completed_at'];
                $response['message'] = 'Course completion status retrieved';
            }
        }
    } elseif ($_SERVER['REQUEST_METHOD'] === 'GET') {
        // Handle GET requests (status check)
        $user_id = filter_var($_GET['user_id'] ?? null, FILTER_VALIDATE_INT);
        $course_id = filter_var($_GET['course_id'] ?? null, FILTER_VALIDATE_INT);
        
        if ($user_id !== false && $course_id !== false && $user_id !== null && $course_id !== null) {
            // Use the same query as above for consistency
            $check_query = "SELECT completed_at FROM course_completion 
                          WHERE user_id = :user_id AND course_id = :course_id";
            $check_stmt = $db->prepare($check_query);
            $check_stmt->bindValue(':user_id', $user_id, PDO::PARAM_INT);
            $check_stmt->bindValue(':course_id', $course_id, PDO::PARAM_INT);
            $check_stmt->execute();
            
            $result = $check_stmt->fetch(PDO::FETCH_ASSOC);
            
            $response['success'] = true;
            $response['is_completed'] = !empty($result['completed_at']);
            $response['completed_at'] = $result['completed_at'];
            $response['message'] = 'Course completion status retrieved';
        }
    }
} catch (Exception $e) {
    error_log("Error in course_completion.php: " . $e->getMessage());
    $response['message'] = 'Error: ' . $e->getMessage();
    http_response_code(500);
}

echo json_encode($response);
?>