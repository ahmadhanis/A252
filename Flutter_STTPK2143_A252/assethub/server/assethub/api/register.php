<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");
date_default_timezone_set('Asia/Kuala_Lumpur');

require_once "db.php";
require_once "mail_helper.php";

$data = json_decode(file_get_contents("php://input"), true);

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

$hashedPassword = password_hash($password, PASSWORD_DEFAULT);
$createdAt = date('Y-m-d H:i:s');
$verificationCode = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
$verificationToken = bin2hex(random_bytes(32));
$verificationExpiresAt = date('Y-m-d H:i:s', strtotime('+24 hours'));
$verifyUrl = assethub_build_verify_url($verificationToken, $verificationCode);

try {
    $stmt = $db->prepare("SELECT id FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);

    if ($stmt->fetch()) {
        echo json_encode([
            "status" => "error",
            "message" => "Email already registered"
        ]);
        exit;
    }

    $db->beginTransaction();

    $insert = $db->prepare("
        INSERT INTO users (
            name, email, phone, password, role, profile_image, created_at,
            is_verified, verification_code, verification_token,
            verification_expires_at, verified_at
        )
        VALUES (?, ?, ?, ?, ?, '', ?, 0, ?, ?, ?, '')
    ");

    $insert->execute([
        $name,
        $email,
        $phone,
        $hashedPassword,
        $role,
        $createdAt,
        $verificationCode,
        $verificationToken,
        $verificationExpiresAt
    ]);

    assethub_send_verification_mail($email, $name, $verificationCode, $verifyUrl);

    $db->commit();

    echo json_encode([
        "status" => "success",
        "message" => "Account created. Please check your email for the OTP confirmation link."
    ]);
} catch (Throwable $e) {
    if ($db->inTransaction()) {
        $db->rollBack();
    }
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
