<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");
date_default_timezone_set('Asia/Kuala_Lumpur');
require_once "db.php";

// Get POST data (JSON)
$data = json_decode(file_get_contents("php://input"), true);

// Validate input
if (
    empty($data["name"]) ||
    empty($data["email"]) ||
    empty($data["password"]) ||
    empty($data["role"])
) {
    echo json_encode([
        "status" => "error",
        "message" => "All fields are required"
    ]);
    exit;
}

$name = trim($data["name"]);
$email = trim($data["email"]);
$password = $data["password"];
$role = trim($data["role"]);

// Validate email format
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode([
        "status" => "error",
        "message" => "Invalid email format"
    ]);
    exit;
}

// Hash password
$hashed_password = password_hash($password, PASSWORD_DEFAULT);

try {

    // Check duplicate email
    $stmt = $db->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->execute([$email]);

    if ($stmt->fetch()) {
        echo json_encode([
            "status" => "error",
            "message" => "Email already registered"
        ]);
        exit;
    }

    // Insert user
    $stmt = $db->prepare("
        INSERT INTO users (name, email, password, role)
        VALUES (?, ?, ?, ?)
    ");

    $stmt->execute([$name, $email, $hashed_password, $role]);

    echo json_encode([
        "status" => "success",
        "message" => "Registration successful"
    ]);

} catch (PDOException $e) {
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>