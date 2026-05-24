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
            a.name AS asset_name,
            a.category AS asset_category,
            approver.name AS approved_by_name
        FROM loan_requests lr
        INNER JOIN users u ON u.id = lr.user_id
        INNER JOIN assets a ON a.id = lr.asset_id
        LEFT JOIN users approver ON approver.id = lr.approved_by
    ";

    if (strcasecmp($role, "Admin") !== 0 && $userId > 0) {
        $sql .= " WHERE lr.user_id = :user_id";
    }

    $sql .= " ORDER BY CASE lr.status
        WHEN 'Pending' THEN 1
        WHEN 'Approved' THEN 2
        WHEN 'Rejected' THEN 3
        WHEN 'Returned' THEN 4
        ELSE 5
    END, lr.created_at DESC";

    $stmt = $db->prepare($sql);
    if (strcasecmp($role, "Admin") !== 0 && $userId > 0) {
        $stmt->bindValue(":user_id", $userId, PDO::PARAM_INT);
    }
    $stmt->execute();

    echo json_encode([
        "status" => "success",
        "loans" => $stmt->fetchAll(PDO::FETCH_ASSOC)
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
