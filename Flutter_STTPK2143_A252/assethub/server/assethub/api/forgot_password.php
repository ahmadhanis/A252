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
        SELECT id, name, email
        FROM users
        WHERE email = ?
        LIMIT 1
    ");
    $stmt->execute([$email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($user) {
        $resetToken = bin2hex(random_bytes(32));
        $resetExpiresAt = date('Y-m-d H:i:s', strtotime('+60 minutes'));
        $resetUrl = assethub_build_reset_url($resetToken);

        $update = $db->prepare("
            UPDATE users
            SET password_reset_token = ?, password_reset_expires_at = ?
            WHERE id = ?
        ");
        $update->execute([
            $resetToken,
            $resetExpiresAt,
            (int) $user["id"],
        ]);

        assethub_send_password_reset_mail(
            (string) $user["email"],
            (string) $user["name"],
            $resetUrl
        );
    }

    echo json_encode([
        "status" => "success",
        "message" => "If the account exists, a password reset link has been sent."
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
