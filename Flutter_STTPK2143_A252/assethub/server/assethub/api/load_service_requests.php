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
            sr.id,
            sr.user_id,
            sr.service_type,
            sr.title,
            sr.details,
            sr.preferred_date,
            sr.status,
            sr.admin_notes,
            sr.created_at,
            sr.updated_at,
            u.name AS user_name,
            u.email AS user_email,
            u.phone AS user_phone
        FROM service_requests sr
        INNER JOIN users u ON u.id = sr.user_id
    ";

    if (strcasecmp($role, "Admin") !== 0 && $userId > 0) {
        $sql .= " WHERE sr.user_id = :user_id";
    }

    $sql .= " ORDER BY CASE sr.status
        WHEN 'Pending' THEN 1
        WHEN 'In Progress' THEN 2
        WHEN 'Completed' THEN 3
        WHEN 'Rejected' THEN 4
        ELSE 5
    END, sr.created_at DESC";

    $stmt = $db->prepare($sql);
    if (strcasecmp($role, "Admin") !== 0 && $userId > 0) {
        $stmt->bindValue(":user_id", $userId, PDO::PARAM_INT);
    }
    $stmt->execute();

    echo json_encode([
        "status" => "success",
        "services" => $stmt->fetchAll(PDO::FETCH_ASSOC)
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
