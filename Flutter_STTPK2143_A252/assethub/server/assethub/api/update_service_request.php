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

$serviceId = (int) ($data["service_id"] ?? 0);
$status = trim($data["status"] ?? "");
$adminNotes = trim($data["admin_notes"] ?? "");

$allowedStatuses = ["Pending", "In Progress", "Completed", "Rejected"];
if ($serviceId <= 0 || !in_array($status, $allowedStatuses, true)) {
    echo json_encode([
        "status" => "error",
        "message" => "Invalid request update"
    ]);
    exit;
}

try {
    $stmt = $db->prepare("
        UPDATE service_requests
        SET status = ?, admin_notes = ?, updated_at = datetime('now', 'localtime')
        WHERE id = ?
    ");
    $stmt->execute([$status, $adminNotes, $serviceId]);

    echo json_encode([
        "status" => "success",
        "message" => "Service request updated"
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
