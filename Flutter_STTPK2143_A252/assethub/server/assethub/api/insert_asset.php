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

$name = trim($_POST["name"] ?? "");
$category = trim($_POST["category"] ?? "");
$quantity = trim($_POST["quantity"] ?? "");
$price = trim($_POST["price"] ?? "");
$description = trim($_POST["description"] ?? "");
$imageData = trim($_POST["image"] ?? "");

if ($name === "" || $category === "" || $quantity === "" || $price === "" || $imageData === "") {
    json_error("All fields are required");
}

if (!is_numeric($quantity) || !is_numeric($price)) {
    json_error("Quantity and price must be numbers");
}

$quantity = (int) $quantity;
$price = (float) $price;
$createdAt = date('Y-m-d H:i:s');

$uploadDir = __DIR__ . "/../uploads/assets/";
if (!is_dir($uploadDir) && !mkdir($uploadDir, 0775, true) && !is_dir($uploadDir)) {
    json_error("Failed to create upload directory");
}

try {
    $stmt = $db->prepare("
        INSERT INTO assets (name, category, quantity, price, description, image, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([$name, $category, $quantity, $price, $description, "", $createdAt]);

    $assetId = (int) $db->lastInsertId();
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
    if (file_put_contents($uploadDir . $savedImageName, $decodedImage) === false) {
        throw new RuntimeException("Failed to save image");
    }

    $stmt = $db->prepare("UPDATE assets SET image = ? WHERE id = ?");
    $stmt->execute([$savedImageName, $assetId]);

    echo json_encode([
        "status" => "success",
        "message" => "Asset inserted successfully",
        "asset" => [
            "id" => $assetId,
            "name" => $name,
            "category" => $category,
            "quantity" => $quantity,
            "price" => $price,
            "description" => $description,
            "image" => $savedImageName,
            "created_at" => $createdAt
        ]
    ]);
} catch (Throwable $e) {
    json_error($e->getMessage(), 500);
}
?>
