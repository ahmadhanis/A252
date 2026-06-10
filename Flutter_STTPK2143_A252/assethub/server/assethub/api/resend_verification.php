<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");
date_default_timezone_set('Asia/Kuala_Lumpur');

require_once "db.php";
require_once "mail_helper.php";

$data = json_decode(file_get_contents("php://input"), true);
$email = trim($data["email"] ?? "");

if ($email === "" || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode([
        "status" => "error",
        "message" => "Please enter a valid email address"
    ]);
    exit;
}

try {
    $stmt = $db->prepare("
        SELECT id, name, email, is_verified
        FROM users
        WHERE email = ?
        LIMIT 1
    ");
    $stmt->execute([$email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        echo json_encode([
            "status" => "success",
            "message" => "If this account exists, a verification email has been sent."
        ]);
        exit;
    }

    if ((int) ($user["is_verified"] ?? 0) === 1) {
        echo json_encode([
            "status" => "error",
            "message" => "This account is already verified."
        ]);
        exit;
    }

    $verificationCode = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    $verificationToken = bin2hex(random_bytes(32));
    $verificationExpiresAt = date('Y-m-d H:i:s', strtotime('+24 hours'));
    $verifyUrl = assethub_build_verify_url($verificationToken, $verificationCode);

    $update = $db->prepare("
        UPDATE users
        SET verification_code = ?, verification_token = ?, verification_expires_at = ?
        WHERE id = ?
    ");
    $update->execute([
        $verificationCode,
        $verificationToken,
        $verificationExpiresAt,
        (int) $user["id"],
    ]);

    assethub_send_verification_mail(
        (string) $user["email"],
        (string) $user["name"],
        $verificationCode,
        $verifyUrl
    );

    echo json_encode([
        "status" => "success",
        "message" => "A new OTP confirmation email has been sent."
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
