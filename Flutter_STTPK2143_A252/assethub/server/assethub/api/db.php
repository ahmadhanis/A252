<?php
// db.php

$db_file = __DIR__ . "/assethub.db";

try {
    $db = new PDO("sqlite:" . $db_file);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Create table if not exists
    $db->exec("
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            password TEXT NOT NULL,
            role TEXT NOT NULL,
            created_at DATETIME DEFAULT (datetime('now', 'localtime'))
        )
    ");

    $userColumns = $db->query("PRAGMA table_info(users)")->fetchAll(PDO::FETCH_ASSOC);
    $hasPhoneColumn = false;
    foreach ($userColumns as $column) {
        if (($column["name"] ?? "") === "phone") {
            $hasPhoneColumn = true;
            break;
        }
    }
    if (!$hasPhoneColumn) {
        $db->exec("ALTER TABLE users ADD COLUMN phone TEXT NOT NULL DEFAULT ''");
    }

    $userColumns = $db->query("PRAGMA table_info(users)")->fetchAll(PDO::FETCH_ASSOC);
    $userColumnNames = array_map(fn($column) => $column["name"] ?? "", $userColumns);
    if (!in_array("is_verified", $userColumnNames, true)) {
        $db->exec("ALTER TABLE users ADD COLUMN is_verified INTEGER NOT NULL DEFAULT 1");
    }
    if (!in_array("verification_code", $userColumnNames, true)) {
        $db->exec("ALTER TABLE users ADD COLUMN verification_code TEXT DEFAULT ''");
    }
    if (!in_array("verification_token", $userColumnNames, true)) {
        $db->exec("ALTER TABLE users ADD COLUMN verification_token TEXT DEFAULT ''");
    }
    if (!in_array("verification_expires_at", $userColumnNames, true)) {
        $db->exec("ALTER TABLE users ADD COLUMN verification_expires_at TEXT DEFAULT ''");
    }
    if (!in_array("verified_at", $userColumnNames, true)) {
        $db->exec("ALTER TABLE users ADD COLUMN verified_at TEXT DEFAULT ''");
    }
    if (!in_array("password_reset_token", $userColumnNames, true)) {
        $db->exec("ALTER TABLE users ADD COLUMN password_reset_token TEXT DEFAULT ''");
    }
    if (!in_array("password_reset_expires_at", $userColumnNames, true)) {
        $db->exec("ALTER TABLE users ADD COLUMN password_reset_expires_at TEXT DEFAULT ''");
    }
    if (!in_array("profile_image", $userColumnNames, true)) {
        $db->exec("ALTER TABLE users ADD COLUMN profile_image TEXT DEFAULT ''");
    }
    $db->exec("UPDATE users SET is_verified = 1 WHERE role = 'Admin'");

    $db->exec("
        CREATE TABLE IF NOT EXISTS assets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            price REAL NOT NULL,
            description TEXT,
            image TEXT,
            created_at DATETIME DEFAULT (datetime('now', 'localtime'))
        )
    ");

    $db->exec("
        CREATE TABLE IF NOT EXISTS loan_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            asset_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            purpose TEXT NOT NULL,
            loan_date TEXT NOT NULL,
            due_date TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'Pending',
            admin_notes TEXT DEFAULT '',
            approved_by INTEGER,
            approved_at TEXT,
            returned_at TEXT,
            created_at DATETIME DEFAULT (datetime('now', 'localtime')),
            FOREIGN KEY (user_id) REFERENCES users(id),
            FOREIGN KEY (asset_id) REFERENCES assets(id),
            FOREIGN KEY (approved_by) REFERENCES users(id)
        )
    ");

    $db->exec("
        CREATE TABLE IF NOT EXISTS service_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            service_type TEXT NOT NULL,
            title TEXT NOT NULL,
            details TEXT NOT NULL,
            preferred_date TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'Pending',
            admin_notes TEXT DEFAULT '',
            created_at DATETIME DEFAULT (datetime('now', 'localtime')),
            updated_at DATETIME DEFAULT (datetime('now', 'localtime')),
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
    ");

} catch (PDOException $e) {
    die(json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]));
}
?>
