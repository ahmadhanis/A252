<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Content-Type: application/json");

if (($_SERVER["REQUEST_METHOD"] ?? "") === "OPTIONS") {
    http_response_code(200);
    exit;
}

require_once "db.php";

try {
    $page = max(1, (int) ($_GET["page"] ?? 1));
    $limit = max(1, min(100, (int) ($_GET["limit"] ?? 10)));
    $search = trim($_GET["search"] ?? "");
    $category = trim($_GET["category"] ?? "All");
    $whereClauses = [];
    $params = [];

    if ($search !== "") {
        $whereClauses[] = "(name LIKE :search OR category LIKE :search OR description LIKE :search)";
        $params[":search"] = "%" . $search . "%";
    }

    if ($category !== "" && strcasecmp($category, "All") !== 0) {
        $whereClauses[] = "category = :category";
        $params[":category"] = $category;
    }

    $whereSql = empty($whereClauses) ? "" : " WHERE " . implode(" AND ", $whereClauses);

    $countStmt = $db->prepare("SELECT COUNT(*) FROM assets" . $whereSql);
    foreach ($params as $key => $value) {
        $countStmt->bindValue($key, $value, PDO::PARAM_STR);
    }
    $countStmt->execute();
    $totalItems = (int) $countStmt->fetchColumn();
    $totalPages = max(1, (int) ceil($totalItems / $limit));

    if ($page > $totalPages) {
        $page = $totalPages;
    }

    $offset = ($page - 1) * $limit;

    $stmt = $db->prepare("
        SELECT id, name, category, quantity, price, description, image, created_at
        FROM assets
        $whereSql
        ORDER BY id DESC
        LIMIT :limit OFFSET :offset
    ");
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value, PDO::PARAM_STR);
    }
    $stmt->bindValue(":limit", $limit, PDO::PARAM_INT);
    $stmt->bindValue(":offset", $offset, PDO::PARAM_INT);
    $stmt->execute();

    $assets = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        "status" => "success",
        "assets" => $assets,
        "current_page" => $page,
        "per_page" => $limit,
        "total_items" => $totalItems,
        "total_pages" => $totalPages
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
