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
    $role = trim($_GET["role"] ?? "");
    $userId = (int) ($_GET["user_id"] ?? 0);
    $page = max(1, (int) ($_GET["page"] ?? 1));
    $limit = max(1, min(100, (int) ($_GET["limit"] ?? 10)));
    $offset = ($page - 1) * $limit;
    $search = trim($_GET["search"] ?? "");
    $statusFilter = trim($_GET["status"] ?? "All");

    $whereClauses = [];
    $params = [];

    if (strcasecmp($role, "Admin") !== 0 && $userId > 0) {
        $whereClauses[] = "lr.user_id = :user_id";
        $params[":user_id"] = [$userId, PDO::PARAM_INT];
    }

    if ($search !== "") {
        $whereClauses[] = "(
            a.name LIKE :search OR
            a.category LIKE :search OR
            u.name LIKE :search OR
            u.email LIKE :search OR
            u.phone LIKE :search OR
            lr.purpose LIKE :search
        )";
        $params[":search"] = ["%" . $search . "%", PDO::PARAM_STR];
    }

    if ($statusFilter !== "" && strcasecmp($statusFilter, "All") !== 0) {
        $whereClauses[] = "lr.status = :status";
        $params[":status"] = [$statusFilter, PDO::PARAM_STR];
    }

    $whereSql = "";
    if (!empty($whereClauses)) {
        $whereSql = " WHERE " . implode(" AND ", $whereClauses);
    }

    $fromSql = "
        FROM loan_requests lr
        INNER JOIN users u ON u.id = lr.user_id
        INNER JOIN assets a ON a.id = lr.asset_id
        LEFT JOIN users approver ON approver.id = lr.approved_by
    ";

    $countStmt = $db->prepare("SELECT COUNT(*) " . $fromSql . $whereSql);
    foreach ($params as $key => [$value, $type]) {
        $countStmt->bindValue($key, $value, $type);
    }
    $countStmt->execute();
    $totalItems = (int) $countStmt->fetchColumn();
    $totalPages = max(1, (int) ceil($totalItems / $limit));
    if ($page > $totalPages) {
        $page = $totalPages;
        $offset = ($page - 1) * $limit;
    }

    $summaryStmt = $db->prepare("
        SELECT
            SUM(CASE WHEN lr.status = 'Pending' THEN 1 ELSE 0 END) AS pending_count,
            SUM(CASE WHEN lr.status = 'Approved' THEN 1 ELSE 0 END) AS approved_count,
            SUM(CASE WHEN lr.status = 'Returned' THEN 1 ELSE 0 END) AS returned_count
        " . $fromSql . $whereSql
    );
    foreach ($params as $key => [$value, $type]) {
        $summaryStmt->bindValue($key, $value, $type);
    }
    $summaryStmt->execute();
    $summary = $summaryStmt->fetch(PDO::FETCH_ASSOC) ?: [];

    $sql = "
        SELECT
            lr.id,
            lr.user_id,
            lr.asset_id,
            lr.quantity,
            lr.purpose,
            lr.loan_date,
            lr.due_date,
            lr.status,
            lr.admin_notes,
            lr.approved_by,
            lr.approved_at,
            lr.returned_at,
            lr.created_at,
            u.name AS user_name,
            u.email AS user_email,
            u.phone AS user_phone,
            u.profile_image AS user_profile_image,
            a.name AS asset_name,
            a.category AS asset_category,
            approver.name AS approved_by_name
        " . $fromSql . $whereSql . "
    ";

    $sql .= " ORDER BY CASE lr.status
        WHEN 'Pending' THEN 1
        WHEN 'Approved' THEN 2
        WHEN 'Rejected' THEN 3
        WHEN 'Returned' THEN 4
        ELSE 5
    END, lr.created_at DESC
    LIMIT :limit OFFSET :offset";

    $stmt = $db->prepare($sql);
    foreach ($params as $key => [$value, $type]) {
        $stmt->bindValue($key, $value, $type);
    }
    $stmt->bindValue(":limit", $limit, PDO::PARAM_INT);
    $stmt->bindValue(":offset", $offset, PDO::PARAM_INT);
    $stmt->execute();

    echo json_encode([
        "status" => "success",
        "loans" => $stmt->fetchAll(PDO::FETCH_ASSOC),
        "current_page" => $page,
        "per_page" => $limit,
        "total_items" => $totalItems,
        "total_pages" => $totalPages,
        "summary" => [
            "pending_count" => (int) ($summary["pending_count"] ?? 0),
            "approved_count" => (int) ($summary["approved_count"] ?? 0),
            "returned_count" => (int) ($summary["returned_count"] ?? 0),
        ],
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
