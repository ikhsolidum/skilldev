<?php
require_once 'mobile-connect.php';

$database = new Database();
$db = $database->getConnection();

if ($db) {
    echo "Connection successful!";
} else {
    echo "Connection failed.";
}
?>