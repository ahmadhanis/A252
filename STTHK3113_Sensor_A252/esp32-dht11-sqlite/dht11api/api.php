<?php

declare(strict_types=1);

header('Content-Type: application/json');

date_default_timezone_set('Asia/Kuala_Lumpur');

$databaseFile = __DIR__ . DIRECTORY_SEPARATOR . 'sensor.sqlite';

function respond(int $statusCode, array $payload): void
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_PRETTY_PRINT);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    respond(405, [
        'success' => false,
        'message' => 'Only GET requests are allowed.',
    ]);
}

$temperature = $_GET['temperature'] ?? $_GET['temp'] ?? null;
$humidity = $_GET['humidity'] ?? $_GET['hum'] ?? null;
$device = isset($_GET['device']) ? trim((string) $_GET['device']) : null;

if ($temperature === null || $humidity === null) {
    respond(400, [
        'success' => false,
        'message' => 'Missing required values: temperature and humidity.',
        'example' => 'api.php?temperature=29.4&humidity=71.2&device=esp32-01',
    ]);
}

if (!is_numeric((string) $temperature) || !is_numeric((string) $humidity)) {
    respond(400, [
        'success' => false,
        'message' => 'Temperature and humidity must be numeric.',
    ]);
}

$temperature = (float) $temperature;
$humidity = (float) $humidity;
$createdAt = date('Y-m-d H:i:s');

try {
    $pdo = new PDO('sqlite:' . $databaseFile);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS sensor_readings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device TEXT NULL,
            temperature REAL NOT NULL,
            humidity REAL NOT NULL,
            created_at TEXT NOT NULL
        )'
    );

    $statement = $pdo->prepare(
        'INSERT INTO sensor_readings (device, temperature, humidity, created_at)
         VALUES (:device, :temperature, :humidity, :created_at)'
    );

    $statement->execute([
        ':device' => $device !== '' ? $device : null,
        ':temperature' => $temperature,
        ':humidity' => $humidity,
        ':created_at' => $createdAt,
    ]);

    respond(201, [
        'success' => true,
        'message' => 'Sensor data saved.',
        'id' => (int) $pdo->lastInsertId(),
        'data' => [
            'device' => $device,
            'temperature' => $temperature,
            'humidity' => $humidity,
            'created_at' => $createdAt,
        ],
    ]);
} catch (PDOException $exception) {
    respond(500, [
        'success' => false,
        'message' => 'Failed to save sensor data.',
        'error' => $exception->getMessage(),
    ]);
}
