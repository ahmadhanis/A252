<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json");

if (($_SERVER["REQUEST_METHOD"] ?? "") === "OPTIONS") {
    http_response_code(200);
    exit;
}

require_once "db.php";

$data = json_decode(file_get_contents("php://input"), true);

$userId = (int) ($data["user_id"] ?? 0);
$serviceType = trim($data["service_type"] ?? "");
$title = trim($data["title"] ?? "");
$details = trim($data["details"] ?? "");
$preferredDate = trim($data["preferred_date"] ?? "");

if ($userId <= 0 || $serviceType === "" || $title === "" || $details === "" || $preferredDate === "") {
    echo json_encode([
        "status" => "error",
        "message" => "All fields are required"
    ]);
    exit;
}

try {
    $userStmt = $db->prepare("SELECT phone FROM users WHERE id = ? LIMIT 1");
    $userStmt->execute([$userId]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        throw new RuntimeException("User not found");
    }

    if (trim((string) ($user["phone"] ?? "")) === "") {
        throw new RuntimeException("Phone number is required before requesting a service");
    }

    $stmt = $db->prepare("
        INSERT INTO service_requests (
            user_id, service_type, title, details, preferred_date, status, admin_notes
        ) VALUES (?, ?, ?, ?, ?, 'Pending', '')
    ");
    $stmt->execute([$userId, $serviceType, $title, $details, $preferredDate]);

    echo json_encode([
        "status" => "success",
        "message" => "Service request submitted"
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
