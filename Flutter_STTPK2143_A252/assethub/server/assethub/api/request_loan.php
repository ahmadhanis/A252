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
$assetId = (int) ($data["asset_id"] ?? 0);
$quantity = (int) ($data["quantity"] ?? 0);
$purpose = trim($data["purpose"] ?? "");
$loanDate = trim($data["loan_date"] ?? "");
$dueDate = trim($data["due_date"] ?? "");

if ($userId <= 0 || $assetId <= 0 || $quantity <= 0 || $purpose === "" || $loanDate === "" || $dueDate === "") {
    echo json_encode([
        "status" => "error",
        "message" => "All fields are required"
    ]);
    exit;
}

try {
    $assetStmt = $db->prepare("SELECT quantity FROM assets WHERE id = ? LIMIT 1");
    $assetStmt->execute([$assetId]);
    $asset = $assetStmt->fetch(PDO::FETCH_ASSOC);

    if (!$asset) {
        throw new RuntimeException("Asset not found");
    }

    if ($quantity > (int) $asset["quantity"]) {
        throw new RuntimeException("Requested quantity exceeds available stock");
    }

    $stmt = $db->prepare("
        INSERT INTO loan_requests (
            user_id, asset_id, quantity, purpose, loan_date, due_date, status, admin_notes
        ) VALUES (?, ?, ?, ?, ?, ?, 'Pending', '')
    ");
    $stmt->execute([$userId, $assetId, $quantity, $purpose, $loanDate, $dueDate]);

    echo json_encode([
        "status" => "success",
        "message" => "Loan request submitted"
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
