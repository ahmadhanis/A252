<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
    http_response_code(200);
    exit;
}

date_default_timezone_set('Asia/Kuala_Lumpur');
require_once "db.php";

function json_error($message, $code = 400) {
    http_response_code($code);
    echo json_encode([
        "status" => "error",
        "message" => $message
    ]);
    exit;
}

$id = trim($_POST["id"] ?? "");
$name = trim($_POST["name"] ?? "");
$phone = trim($_POST["phone"] ?? "");
$oldPassword = $_POST["old_password"] ?? "";
$newPassword = $_POST["new_password"] ?? "";
$confirmNewPassword = $_POST["confirm_new_password"] ?? "";

if ($id === "" || $name === "" || $phone === "") {
    json_error("Name, phone number, and user ID are required");
}

if (!ctype_digit($id)) {
    json_error("Invalid user ID");
}

if (!preg_match('/^[0-9+\-\s]{8,20}$/', $phone)) {
    json_error("Invalid phone number format");
}

$userId = (int) $id;
$uploadDir = __DIR__ . "/../uploads/profiles/";
if (!is_dir($uploadDir) && !mkdir($uploadDir, 0775, true) && !is_dir($uploadDir)) {
    json_error("Failed to create profile upload directory", 500);
}

try {
    $stmt = $db->prepare("
        SELECT id, email, role, created_at, profile_image, password
        FROM users
        WHERE id = ?
        LIMIT 1
    ");
    $stmt->execute([$userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        json_error("User not found", 404);
    }

    $profileImage = (string) ($user["profile_image"] ?? "");

    if (isset($_FILES["image"]) && is_array($_FILES["image"]) && ($_FILES["image"]["error"] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_NO_FILE) {
        if (($_FILES["image"]["error"] ?? UPLOAD_ERR_OK) !== UPLOAD_ERR_OK) {
            json_error("Failed to upload image", 500);
        }

        $tempPath = $_FILES["image"]["tmp_name"] ?? "";
        $mimeType = mime_content_type($tempPath);
        $allowedTypes = [
            "image/jpeg" => "jpg",
            "image/png" => "png",
            "image/webp" => "webp",
        ];

        if (!isset($allowedTypes[$mimeType])) {
            json_error("Unsupported image format");
        }

        $extension = $allowedTypes[$mimeType];
        $savedImageName = "user_" . $userId . "_" . time() . "." . $extension;
        $targetPath = $uploadDir . $savedImageName;

        if ($profileImage !== "") {
            $oldPath = $uploadDir . $profileImage;
            if (file_exists($oldPath)) {
                @unlink($oldPath);
            }
        }

        if (!move_uploaded_file($tempPath, $targetPath)) {
            json_error("Failed to save profile image", 500);
        }

        $profileImage = $savedImageName;
    }

    $isChangingPassword = $oldPassword !== "" || $newPassword !== "" || $confirmNewPassword !== "";

    if ($isChangingPassword) {
        if ($oldPassword === "" || $newPassword === "" || $confirmNewPassword === "") {
            json_error("Old password, new password, and confirmation are required");
        }

        if (!password_verify($oldPassword, (string) ($user["password"] ?? ""))) {
            json_error("Old password is incorrect");
        }

        if (strlen($newPassword) < 6) {
            json_error("New password must be at least 6 characters");
        }

        if ($newPassword !== $confirmNewPassword) {
            json_error("New password and confirmation do not match");
        }
    }

    if ($isChangingPassword) {
        $hashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);
        $update = $db->prepare("
            UPDATE users
            SET name = ?, phone = ?, password = ?, profile_image = ?
            WHERE id = ?
        ");
        $update->execute([$name, $phone, $hashedPassword, $profileImage, $userId]);
    } else {
        $update = $db->prepare("
            UPDATE users
            SET name = ?, phone = ?, profile_image = ?
            WHERE id = ?
        ");
        $update->execute([$name, $phone, $profileImage, $userId]);
    }

    echo json_encode([
        "status" => "success",
        "message" => "Profile updated successfully",
        "user" => [
            "id" => $userId,
            "name" => $name,
            "email" => (string) ($user["email"] ?? ""),
            "phone" => $phone,
            "role" => (string) ($user["role"] ?? ""),
            "profile_image" => $profileImage,
            "created_at" => (string) ($user["created_at"] ?? ""),
        ],
    ]);
} catch (Throwable $e) {
    json_error($e->getMessage(), 500);
}
?>
