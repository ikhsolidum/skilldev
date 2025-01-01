<?php
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

// Get chat messages
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $user_id = isset($_GET['user_id']) ? $_GET['user_id'] : null;
    
    if (!$user_id) {
        $response['message'] = 'User ID is required';
        http_response_code(400);
    } else {
        try {
            $query = "SELECT * FROM messages WHERE user_id = :user_id OR sender_id = :sender_id ORDER BY created_at ASC";
            $stmt = $db->prepare($query);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->bindParam(':sender_id', $user_id);
            $stmt->execute();
            
            $messages = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            if ($messages) {
                $response['success'] = true;
                $response['messages'] = $messages;
                http_response_code(200);
            } else {
                $response['message'] = 'No messages found';
                $response['messages'] = [];
                http_response_code(200);
            }
        } catch (PDOException $e) {
            $response['message'] = 'Database error: ' . $e->getMessage();
            http_response_code(500);
        }
    }
}

// Send new message
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"));
    
    if (!isset($data->sender_id) || !isset($data->user_id) || !isset($data->message)) {
        $response['message'] = 'Missing required fields';
        http_response_code(400);
    } else {
        try {
            $query = "INSERT INTO messages (sender_id, user_id, message, reply_to) VALUES (:sender_id, :user_id, :message, :reply_to)";
            $stmt = $db->prepare($query);
            $stmt->bindParam(':sender_id', $data->sender_id);
            $stmt->bindParam(':user_id', $data->user_id);
            $stmt->bindParam(':message', $data->message);
            $stmt->bindParam(':reply_to', $data->reply_to);
            
            if ($stmt->execute()) {
                $response['success'] = true;
                $response['message'] = 'Message sent successfully';
                $response['message_data'] = [
                    'id' => $db->lastInsertId(),
                    'sender_id' => $data->sender_id,
                    'user_id' => $data->user_id,
                    'message' => $data->message,
                    'reply_to' => $data->reply_to,
                    'created_at' => date('Y-m-d H:i:s'),
                    'timestamp' => date('Y-m-d H:i:s')
                ];
                http_response_code(201);
            } else {
                $response['message'] = 'Failed to send message';
                http_response_code(500);
            }
        } catch (PDOException $e) {
            $response['message'] = 'Database error: ' . $e->getMessage();
            http_response_code(500);
        }
    }
}

echo json_encode($response);