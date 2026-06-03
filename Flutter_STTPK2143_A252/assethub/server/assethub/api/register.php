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
    empty($data["phone"]) ||
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
$phone = trim($data["phone"]);
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

if (!preg_match('/^[0-9+\-\s]{8,20}$/', $phone)) {
    echo json_encode([
        "status" => "error",
        "message" => "Invalid phone number format"
    ]);
    exit;
}

// Hash password
$hashed_password = password_hash($password, PASSWORD_DEFAULT);
$createdAt = date('Y-m-d H:i:s');

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
        INSERT INTO users (name, email, phone, password, role, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
    ");

    $stmt->execute([$name, $email, $phone, $hashed_password, $role, $createdAt]);

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
