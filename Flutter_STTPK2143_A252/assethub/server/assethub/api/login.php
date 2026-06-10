<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");
date_default_timezone_set('Asia/Kuala_Lumpur');

require_once "db.php";

$data = json_decode(file_get_contents("php://input"), true);

if (empty($data["email"]) || empty($data["password"])) {
    echo json_encode([
        "status" => "error",
        "message" => "Email and password are required"
    ]);
    exit;
}

$email = trim($data["email"]);
$password = $data["password"];

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode([
        "status" => "error",
        "message" => "Invalid email format"
    ]);
    exit;
}

try {
    $stmt = $db->prepare("
        SELECT
            id, name, email, phone, password, role, profile_image, created_at,
            is_verified, verification_code, verification_token, verification_expires_at
        FROM users
        WHERE email = ?
        LIMIT 1
    ");
    $stmt->execute([$email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user || !password_verify($password, $user["password"])) {
        echo json_encode([
            "status" => "error",
            "message" => "Invalid email or password"
        ]);
        exit;
    }

    if ((int) ($user["is_verified"] ?? 0) !== 1) {
        echo json_encode([
            "status" => "error",
            "message" => "Please verify your email first. Check your inbox for the OTP confirmation link."
        ]);
        exit;
    }

    unset($user["password"], $user["verification_code"], $user["verification_token"], $user["verification_expires_at"]);

    echo json_encode([
        "status" => "success",
        "message" => "Login successful",
        "user" => $user
    ]);
} catch (PDOException $e) {
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
