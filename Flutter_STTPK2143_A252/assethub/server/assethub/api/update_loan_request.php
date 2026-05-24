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

$loanId = (int) ($data["loan_id"] ?? 0);
$action = trim($data["action"] ?? "");
$adminId = (int) ($data["admin_id"] ?? 0);
$adminNotes = trim($data["admin_notes"] ?? "");

if ($loanId <= 0 || $action === "") {
    echo json_encode([
        "status" => "error",
        "message" => "Loan id and action are required"
    ]);
    exit;
}

try {
    $stmt = $db->prepare("
        SELECT lr.*, a.quantity AS available_quantity
        FROM loan_requests lr
        INNER JOIN assets a ON a.id = lr.asset_id
        WHERE lr.id = ?
        LIMIT 1
    ");
    $stmt->execute([$loanId]);
    $loan = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$loan) {
        throw new RuntimeException("Loan request not found");
    }

    $db->beginTransaction();

    if ($action === "approve") {
        if ($loan["status"] !== "Pending") {
            throw new RuntimeException("Only pending requests can be approved");
        }

        if ((int) $loan["quantity"] > (int) $loan["available_quantity"]) {
            throw new RuntimeException("Not enough stock to approve this request");
        }

        $updateAsset = $db->prepare("UPDATE assets SET quantity = quantity - ? WHERE id = ?");
        $updateAsset->execute([(int) $loan["quantity"], (int) $loan["asset_id"]]);

        $updateLoan = $db->prepare("
            UPDATE loan_requests
            SET status = 'Approved', admin_notes = ?, approved_by = ?, approved_at = datetime('now', 'localtime')
            WHERE id = ?
        ");
        $updateLoan->execute([$adminNotes, $adminId > 0 ? $adminId : null, $loanId]);
    } elseif ($action === "reject") {
        if ($loan["status"] !== "Pending") {
            throw new RuntimeException("Only pending requests can be rejected");
        }

        $updateLoan = $db->prepare("
            UPDATE loan_requests
            SET status = 'Rejected', admin_notes = ?, approved_by = ?, approved_at = datetime('now', 'localtime')
            WHERE id = ?
        ");
        $updateLoan->execute([$adminNotes, $adminId > 0 ? $adminId : null, $loanId]);
    } elseif ($action === "return") {
        if ($loan["status"] !== "Approved") {
            throw new RuntimeException("Only approved loans can be marked returned");
        }

        $updateAsset = $db->prepare("UPDATE assets SET quantity = quantity + ? WHERE id = ?");
        $updateAsset->execute([(int) $loan["quantity"], (int) $loan["asset_id"]]);

        $updateLoan = $db->prepare("
            UPDATE loan_requests
            SET status = 'Returned', admin_notes = ?, returned_at = datetime('now', 'localtime')
            WHERE id = ?
        ");
        $updateLoan->execute([$adminNotes, $loanId]);
    } else {
        throw new RuntimeException("Unsupported action");
    }

    $db->commit();

    echo json_encode([
        "status" => "success",
        "message" => "Loan request updated"
    ]);
} catch (Throwable $e) {
    if ($db->inTransaction()) {
        $db->rollBack();
    }
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
