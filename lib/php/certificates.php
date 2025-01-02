<?php
ob_start();
ini_set('display_errors', 0);
error_reporting(E_ALL);
ini_set('log_errors', 1);
error_log("Certificates endpoint hit");

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Accept, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

ob_clean();

require_once 'mobile-connect.php';

$response = array('success' => false, 'message' => '', 'certificates' => array());

$userId = isset($_GET['userId']) ? trim($_GET['userId']) : null;

if (!$userId || !is_numeric($userId)) {
    $response['message'] = 'Invalid User ID';
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
                c.image_path,
                c.description,
                c.uploaded_at,
                DATE_FORMAT(uc.assigned_at, '%Y-%m-%d') as assigned_at
            FROM user_certificates uc
            JOIN certifications c ON uc.certificate_id = c.id
            WHERE uc.user_id = :userId AND c.image_path IS NOT NULL
            ORDER BY uc.assigned_at DESC";
            
        $stmt = $db->prepare($query);
        $stmt->bindParam(':userId', $userId, PDO::PARAM_INT);
        
        if (!$stmt->execute()) {
            throw new PDOException("Error executing query");
        }

        $certificates = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if ($certificates) {
            // Update the base URL to include cap_admin/uploads/
            $baseUrl = 'http://bunn.helioho.st/cap_admin/uploads/';
            $certificates = array_map(function($cert) use ($baseUrl) {
                if (!empty($cert['image_path'])) {
                    // Get just the filename from the path
                    $filename = basename($cert['image_path']);
                    
                    // URL encode the filename properly, replacing spaces with %20 and keeping plus signs
                    $encodedFilename = str_replace(
                        [' '], 
                        ['%20'], 
                        $filename
                    );
                    
                    // Construct the full URL
                    $cert['image_path'] = $baseUrl . $encodedFilename;
                }
                
                // Format dates
                $cert['assigned_at'] = date('Y-m-d', strtotime($cert['assigned_at']));
                $cert['uploaded_at'] = date('Y-m-d H:i:s', strtotime($cert['uploaded_at']));
                return $cert;
            }, $certificates);
            
            $response['success'] = true;
            $response['certificates'] = $certificates;
        }
        
        else {
            $response['success'] = true;
            $response['message'] = 'No certificates found';
        }

    } catch (PDOException $e) {
        error_log("Database error: " . $e->getMessage());
        $response['message'] = 'Database error occurred: ' . $e->getMessage();
    }
} else {
    $response['message'] = 'Unable to connect to database';
}

echo json_encode($response);
exit();
?>