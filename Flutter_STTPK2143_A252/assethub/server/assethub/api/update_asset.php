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
$category = trim($_POST["category"] ?? "");
$quantity = trim($_POST["quantity"] ?? "");
$price = trim($_POST["price"] ?? "");
$description = trim($_POST["description"] ?? "");
$imageData = trim($_POST["image"] ?? "NA");

if ($id === "" || $name === "" || $category === "" || $quantity === "" || $price === "" || $description === "") {
    json_error("All fields are required");
}

if (!ctype_digit($id) || !is_numeric($quantity) || !is_numeric($price)) {
    json_error("Invalid asset data");
}

$assetId = (int) $id;
$quantity = (int) $quantity;
$price = (float) $price;

$uploadDir = __DIR__ . "/../uploads/assets/";
if (!is_dir($uploadDir) && !mkdir($uploadDir, 0775, true) && !is_dir($uploadDir)) {
    json_error("Failed to create upload directory");
}

try {
    $stmt = $db->prepare("SELECT image, created_at FROM assets WHERE id = ? LIMIT 1");
    $stmt->execute([$assetId]);
    $existingAsset = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$existingAsset) {
        json_error("Asset not found", 404);
    }

    $savedImageName = (string) ($existingAsset["image"] ?? "");

    if ($imageData !== "" && strtoupper($imageData) !== "NA") {
        if (strpos($imageData, "data:image") === 0) {
            $commaPosition = strpos($imageData, ",");
            if ($commaPosition !== false) {
                $imageData = substr($imageData, $commaPosition + 1);
            }
        }

        $decodedImage = base64_decode($imageData, true);
        if ($decodedImage === false) {
            throw new RuntimeException("Invalid image data");
        }

        $savedImageName = $assetId . ".jpg";
        $targetPath = $uploadDir . $savedImageName;

        if ($savedImageName !== "" && file_exists($targetPath) && !unlink($targetPath)) {
            throw new RuntimeException("Failed to replace old image");
        }

        if (file_put_contents($targetPath, $decodedImage) === false) {
            throw new RuntimeException("Failed to save image");
        }
    }

    $stmt = $db->prepare("
        UPDATE assets
        SET name = ?, category = ?, quantity = ?, price = ?, description = ?, image = ?
        WHERE id = ?
    ");
    $stmt->execute([$name, $category, $quantity, $price, $description, $savedImageName, $assetId]);

    echo json_encode([
        "status" => "success",
        "message" => "Asset updated successfully",
        "asset" => [
            "id" => $assetId,
            "name" => $name,
            "category" => $category,
            "quantity" => $quantity,
            "price" => $price,
            "description" => $description,
            "image" => $savedImageName,
            "created_at" => $existingAsset["created_at"] ?? ""
        ]
    ]);
} catch (Throwable $e) {
    json_error($e->getMessage(), 500);
}
?>
