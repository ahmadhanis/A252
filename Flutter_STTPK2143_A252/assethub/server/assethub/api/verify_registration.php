<?php
require_once "db.php";

$token = trim($_GET["token"] ?? "");
$otp = trim($_GET["otp"] ?? "");
$message = "Invalid verification request.";
$success = false;

if ($token !== "" && $otp !== "") {
    $stmt = $db->prepare("
        SELECT id, name, is_verified, verification_expires_at
        FROM users
        WHERE verification_token = ? AND verification_code = ?
        LIMIT 1
    ");
    $stmt->execute([$token, $otp]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($user) {
        if ((int) ($user["is_verified"] ?? 0) === 1) {
            $message = "This account is already verified. You can return to the app and log in.";
            $success = true;
        } else {
            $expiresAt = trim((string) ($user["verification_expires_at"] ?? ""));
            if ($expiresAt !== "" && strtotime($expiresAt) < time()) {
                $message = "This verification link has expired. Please register again to get a fresh confirmation email.";
            } else {
                $update = $db->prepare("
                    UPDATE users
                    SET is_verified = 1,
                        verification_code = '',
                        verification_token = '',
                        verification_expires_at = '',
                        verified_at = datetime('now', 'localtime')
                    WHERE id = ?
                ");
                $update->execute([(int) $user["id"]]);
                $message = "Email verified successfully for " . htmlspecialchars((string) ($user["name"] ?? "your account"), ENT_QUOTES, "UTF-8") . ". You can now log in from the AssetHub app.";
                $success = true;
            }
        }
    } else {
        $message = "Verification token or OTP is invalid.";
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AssetHub Verification</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f8fafc; margin: 0; padding: 24px; color: #0f172a; }
    .card { max-width: 640px; margin: 40px auto; background: #ffffff; border-radius: 18px; padding: 28px; box-shadow: 0 10px 30px rgba(15, 23, 42, 0.08); }
    .status { display: inline-block; padding: 8px 12px; border-radius: 999px; font-weight: 700; margin-bottom: 16px; }
    .ok { background: #dcfce7; color: #166534; }
    .bad { background: #fee2e2; color: #b91c1c; }
  </style>
</head>
<body>
  <div class="card">
    <div class="status <?php echo $success ? 'ok' : 'bad'; ?>">
      <?php echo $success ? 'Verified' : 'Verification Failed'; ?>
    </div>
    <h1>AssetHub Account Confirmation</h1>
    <p><?php echo $message; ?></p>
    <p>You can close this page and continue in the AssetHub app.</p>
  </div>
</body>
</html>
