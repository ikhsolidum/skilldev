<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
error_log("Courses endpoint hit");

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

$response = array('success' => false, 'message' => '', 'courses' => array());

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
        // Check if we're requesting enrolled courses
        $isEnrolled = isset($_GET['enrolled']) && $_GET['enrolled'] === 'true';
        
        if ($isEnrolled) {
            // Query to get only enrolled courses
            $query = "SELECT lm.id, lm.title, lm.description, lm.content, lm.created_at 
                     FROM learning_modules lm
                     INNER JOIN enrollments e ON lm.id = e.course_id
                     WHERE e.user_id = :userId";
        } else {
            // Query to get all available courses with enrollment status
            $query = "SELECT lm.id, lm.title, lm.description, lm.content, lm.created_at,
                     CASE WHEN e.user_id IS NOT NULL THEN 1 ELSE 0 END as is_enrolled
                     FROM learning_modules lm
                     LEFT JOIN enrollments e ON lm.id = e.course_id AND e.user_id = :userId";
        }
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':userId', $userId);
        $stmt->execute();

        $courses = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if ($courses) {
            $transformedCourses = array_map(function($course) {
                $transformed = [
                    'id' => $course['id'],
                    'title' => $course['title'],
                    'description' => $course['description'],
                    'content' => $course['content'],
                    'created_at' => $course['created_at']
                ];
                
                // Add enrollment status if it exists
                if (isset($course['is_enrolled'])) {
                    $transformed['is_enrolled'] = (bool)$course['is_enrolled'];
                }
                
                return $transformed;
            }, $courses);

            $response['success'] = true;
            $response['courses'] = $transformedCourses;
            http_response_code(200);
        } else {
            $response['message'] = 'No courses found';
            http_response_code(404);
        }
    } catch (PDOException $e) {
        $response['message'] = 'Database error: ' . $e->getMessage();
        error_log("Database error: " . $e->getMessage());
        http_response_code(500);
    }
} else {
    $response['message'] = 'Unable to connect to database';
    http_response_code(500);
}

echo json_encode($response);
?>