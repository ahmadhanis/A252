<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
    http_response_code(200);
    exit;
}

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

if ($id === "") {
    json_error("Asset id is required");
}

if (!ctype_digit($id)) {
    json_error("Invalid asset id");
}

$assetId = (int) $id;
$uploadDir = __DIR__ . "/../uploads/assets/";

try {
    $stmt = $db->prepare("SELECT image FROM assets WHERE id = ? LIMIT 1");
    $stmt->execute([$assetId]);
    $asset = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$asset) {
        json_error("Asset not found", 404);
    }

    $imageName = (string) ($asset["image"] ?? "");
    $imagePath = $uploadDir . $imageName;

    $stmt = $db->prepare("DELETE FROM assets WHERE id = ?");
    $stmt->execute([$assetId]);

    if ($imageName !== "" && file_exists($imagePath) && !unlink($imagePath)) {
        throw new RuntimeException("Asset deleted but image file could not be removed");
    }

    echo json_encode([
        "status" => "success",
        "message" => "Asset deleted successfully"
    ]);
} catch (Throwable $e) {
    json_error($e->getMessage(), 500);
}
?>
