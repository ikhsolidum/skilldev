<?php
class Database {
    private $host = "localhost:3306"; // Updated to match your configuration
    private $db_name = "bunn_skilldev";
    private $username = "bunn_skilldev";
    private $password = "123456";
    public $conn;

    public function getConnection() {
        $this->conn = null;
        
        try {
            // Add error logging
            error_log("Attempting database connection to {$this->host}");
            
            $dsn = "mysql:host=" . $this->host . ";dbname=" . $this->db_name . ";charset=utf8mb4";
            $options = [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ];
            
            $this->conn = new PDO($dsn, $this->username, $this->password, $options);
            error_log("Database connection successful");
            
            return $this->conn;
        } catch(PDOException $exception) {
            error_log("Connection error: " . $exception->getMessage());
            error_log("DSN: mysql:host=" . $this->host . ";dbname=" . $this->db_name);
            error_log("Username: " . $this->username);
            return null;
        }
    }
}