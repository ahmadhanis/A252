<?php
require_once "db.php";

$token = trim($_GET["token"] ?? ($_POST["token"] ?? ""));
$message = "Invalid or expired password reset link.";
$success = false;

function assethub_find_reset_user(PDO $db, string $token): array|false
{
    $stmt = $db->prepare("
        SELECT id, name, email, password_reset_expires_at
        FROM users
        WHERE password_reset_token = ?
        LIMIT 1
    ");
    $stmt->execute([$token]);
    return $stmt->fetch(PDO::FETCH_ASSOC);
}

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $password = $_POST["password"] ?? "";
    $confirmPassword = $_POST["confirm_password"] ?? "";
    $user = $token === "" ? false : assethub_find_reset_user($db, $token);

    if (!$user) {
        $message = "Invalid password reset token.";
    } elseif (trim((string) ($user["password_reset_expires_at"] ?? "")) === "" || strtotime((string) $user["password_reset_expires_at"]) < time()) {
        $message = "This password reset link has expired.";
    } elseif ($password === "" || $confirmPassword === "") {
        $message = "Please fill in both password fields.";
    } elseif ($password !== $confirmPassword) {
        $message = "Passwords do not match.";
    } elseif (strlen($password) < 6) {
        $message = "Password must be at least 6 characters.";
    } else {
        $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
        $update = $db->prepare("
            UPDATE users
            SET password = ?, password_reset_token = '', password_reset_expires_at = ''
            WHERE id = ?
        ");
        $update->execute([$hashedPassword, (int) $user["id"]]);
        $success = true;
        $message = "Password reset successful. You can now return to the app and log in.";
    }
}

$user = $token === "" ? false : assethub_find_reset_user($db, $token);
$isValidToken = $user && trim((string) ($user["password_reset_expires_at"] ?? "")) !== "" && strtotime((string) $user["password_reset_expires_at"]) >= time();
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AssetHub Password Reset</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f8fafc; margin: 0; padding: 24px; color: #0f172a; }
    .card { max-width: 640px; margin: 40px auto; background: #ffffff; border-radius: 18px; padding: 28px; box-shadow: 0 10px 30px rgba(15, 23, 42, 0.08); }
    .status { display: inline-block; padding: 8px 12px; border-radius: 999px; font-weight: 700; margin-bottom: 16px; }
    .ok { background: #dcfce7; color: #166534; }
    .bad { background: #fee2e2; color: #b91c1c; }
    label { display: block; font-weight: 700; margin: 12px 0 6px; }
    input { width: 100%; box-sizing: border-box; padding: 12px; border: 1px solid #cbd5e1; border-radius: 10px; }
    button { margin-top: 16px; background: #1d4ed8; color: #ffffff; border: none; border-radius: 10px; padding: 12px 18px; font-weight: 700; cursor: pointer; }
  </style>
</head>
<body>
  <div class="card">
    <div class="status <?php echo $success ? 'ok' : 'bad'; ?>">
      <?php echo $success ? 'Reset Complete' : 'Password Reset'; ?>
    </div>
    <h1>AssetHub Password Reset</h1>
    <p><?php echo htmlspecialchars($message, ENT_QUOTES, "UTF-8"); ?></p>

    <?php if (!$success && $isValidToken): ?>
      <form method="post">
        <input type="hidden" name="token" value="<?php echo htmlspecialchars($token, ENT_QUOTES, "UTF-8"); ?>">
        <label for="password">New Password</label>
        <input id="password" name="password" type="password" required>

        <label for="confirm_password">Confirm Password</label>
        <input id="confirm_password" name="confirm_password" type="password" required>

        <button type="submit">Reset Password</button>
      </form>
    <?php else: ?>
      <p>You can close this page and continue in the AssetHub app.</p>
    <?php endif; ?>
  </div>
</body>
</html>
