<?php

declare(strict_types=1);

date_default_timezone_set('Asia/Kuala_Lumpur');

$databaseFile = __DIR__ . DIRECTORY_SEPARATOR . 'sensor.sqlite';
$insightCacheFile = __DIR__ . DIRECTORY_SEPARATOR . 'insight_cache.json';
$ollamaUrl = 'http://127.0.0.1:11434/api/generate';
$ollamaModel = 'llama3.2:1b';

function respondJson(int $statusCode, array $payload): void
{
    http_response_code($statusCode);
    header('Content-Type: application/json');
    echo json_encode($payload, JSON_PRETTY_PRINT);
    exit;
}

function formatNumber(mixed $value, int $decimals = 1): string
{
    if ($value === null || $value === '') {
        return '--';
    }

    return number_format((float) $value, $decimals);
}

function loadDashboardData(string $databaseFile): array
{
    if (!file_exists($databaseFile)) {
        throw new RuntimeException('Database not found yet. Send data from the ESP32 first.');
    }

    $pdo = new PDO('sqlite:' . $databaseFile);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $tableExists = (bool) $pdo->query(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'sensor_readings' LIMIT 1"
    )->fetchColumn();

    if (!$tableExists) {
        throw new RuntimeException('The sensor_readings table does not exist yet.');
    }

    $latestReading = $pdo->query(
        'SELECT id, device, temperature, humidity, created_at
         FROM sensor_readings
         ORDER BY id DESC
         LIMIT 1'
    )->fetch(PDO::FETCH_ASSOC) ?: null;

    $summary = $pdo->query(
        'SELECT
            COUNT(*) AS total_readings,
            AVG(temperature) AS avg_temperature,
            AVG(humidity) AS avg_humidity,
            MAX(temperature) AS max_temperature,
            MIN(temperature) AS min_temperature
         FROM sensor_readings'
    )->fetch(PDO::FETCH_ASSOC) ?: [
        'total_readings' => 0,
        'avg_temperature' => null,
        'avg_humidity' => null,
        'max_temperature' => null,
        'min_temperature' => null,
    ];

    $recentReadings = $pdo->query(
        'SELECT id, device, temperature, humidity, created_at
         FROM sensor_readings
         ORDER BY id DESC
         LIMIT 20'
    )->fetchAll(PDO::FETCH_ASSOC);

    $chartRows = $pdo->query(
        'SELECT temperature, humidity, created_at
         FROM sensor_readings
         ORDER BY id DESC
         LIMIT 12'
    )->fetchAll(PDO::FETCH_ASSOC);

    $chartRows = array_reverse($chartRows);
    $chartLabels = [];
    $chartTemperatures = [];
    $chartHumidities = [];

    foreach ($chartRows as $row) {
        $chartLabels[] = date('H:i:s', strtotime((string) $row['created_at']));
        $chartTemperatures[] = (float) $row['temperature'];
        $chartHumidities[] = (float) $row['humidity'];
    }

    return [
        'generated_at' => date('Y-m-d H:i:s'),
        'latest_reading' => $latestReading,
        'summary' => $summary,
        'recent_readings' => $recentReadings,
        'chart' => [
            'labels' => $chartLabels,
            'temperatures' => $chartTemperatures,
            'humidities' => $chartHumidities,
        ],
    ];
}

function readInsightCache(string $cacheFile): ?array
{
    if (!file_exists($cacheFile)) {
        return null;
    }

    $contents = file_get_contents($cacheFile);
    if ($contents === false) {
        return null;
    }

    $decoded = json_decode($contents, true);
    return is_array($decoded) ? $decoded : null;
}

function saveInsightCache(string $cacheFile, array $payload): void
{
    file_put_contents($cacheFile, json_encode($payload, JSON_PRETTY_PRINT));
}

function buildInsightPrompt(array $dashboardData): string
{
    $summary = $dashboardData['summary'];
    $latest = $dashboardData['latest_reading'];
    $recentReadings = array_slice($dashboardData['recent_readings'], 0, 8);

    $recentLines = [];
    foreach ($recentReadings as $reading) {
        $recentLines[] = sprintf(
            '- %s | temp %.1f C | humidity %.1f%% | device %s',
            $reading['created_at'],
            (float) $reading['temperature'],
            (float) $reading['humidity'],
            $reading['device'] !== null && $reading['device'] !== '' ? $reading['device'] : 'unknown'
        );
    }

    return implode("\n", [
        'You are analyzing DHT11 sensor data from an ESP32 dashboard.',
        'Write a short insight in plain English using 2 to 3 sentences.',
        'Mention trend, stability, and any notable anomaly if present.',
        'Do not use markdown bullets. Do not mention being an AI.',
        '',
        'Current summary:',
        sprintf('Total readings: %d', (int) $summary['total_readings']),
        sprintf('Average temperature: %.1f C', (float) $summary['avg_temperature']),
        sprintf('Average humidity: %.1f%%', (float) $summary['avg_humidity']),
        sprintf('Max temperature: %.1f C', (float) $summary['max_temperature']),
        sprintf('Min temperature: %.1f C', (float) $summary['min_temperature']),
        $latest !== null
            ? sprintf(
                'Latest reading: %s | temp %.1f C | humidity %.1f%% | device %s',
                $latest['created_at'],
                (float) $latest['temperature'],
                (float) $latest['humidity'],
                $latest['device'] !== null && $latest['device'] !== '' ? $latest['device'] : 'unknown'
            )
            : 'Latest reading: none',
        '',
        'Recent readings:',
        implode("\n", $recentLines),
    ]);
}

function requestOllamaInsight(string $ollamaUrl, string $model, array $dashboardData): array
{
    $prompt = buildInsightPrompt($dashboardData);
    $payload = json_encode([
        'model' => $model,
        'prompt' => $prompt,
        'stream' => false,
        'options' => [
            'temperature' => 0.3,
            'num_predict' => 120,
        ],
    ], JSON_UNESCAPED_SLASHES);

    if ($payload === false) {
        throw new RuntimeException('Failed to encode Ollama request.');
    }

    $ch = curl_init($ollamaUrl);
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
        CURLOPT_POSTFIELDS => $payload,
        CURLOPT_TIMEOUT => 40,
    ]);

    $response = curl_exec($ch);
    if ($response === false) {
        $error = curl_error($ch);
        curl_close($ch);
        throw new RuntimeException('Ollama request failed: ' . $error);
    }

    $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $decoded = json_decode($response, true);
    if ($httpCode !== 200 || !is_array($decoded) || !isset($decoded['response'])) {
        throw new RuntimeException('Unexpected Ollama response.');
    }

    $insightText = trim((string) $decoded['response']);
    if ($insightText === '') {
        throw new RuntimeException('Ollama returned an empty insight.');
    }

    return [
        'model' => $model,
        'generated_at' => date('Y-m-d H:i:s'),
        'insight' => $insightText,
    ];
}

function getInsight(string $cacheFile, string $ollamaUrl, string $model, array $dashboardData, bool $forceRefresh = false): array
{
    $cacheTtlSeconds = 60;
    $cached = readInsightCache($cacheFile);

    if (!$forceRefresh && is_array($cached) && isset($cached['generated_at'])) {
        $cacheAge = time() - strtotime((string) $cached['generated_at']);
        if ($cacheAge >= 0 && $cacheAge < $cacheTtlSeconds) {
            return $cached;
        }
    }

    $freshInsight = requestOllamaInsight($ollamaUrl, $model, $dashboardData);
    saveInsightCache($cacheFile, $freshInsight);
    return $freshInsight;
}

if (isset($_GET['format']) && $_GET['format'] === 'json') {
    try {
        respondJson(200, [
            'success' => true,
            'data' => loadDashboardData($databaseFile),
        ]);
    } catch (Throwable $exception) {
        respondJson(500, [
            'success' => false,
            'message' => $exception->getMessage(),
        ]);
    }
}

if (isset($_GET['format']) && $_GET['format'] === 'insight') {
    try {
        $dashboardData = loadDashboardData($databaseFile);
        $forceRefresh = isset($_GET['refresh']) && $_GET['refresh'] === '1';

        respondJson(200, [
            'success' => true,
            'data' => getInsight($insightCacheFile, $ollamaUrl, $ollamaModel, $dashboardData, $forceRefresh),
        ]);
    } catch (Throwable $exception) {
        respondJson(500, [
            'success' => false,
            'message' => $exception->getMessage(),
        ]);
    }
}

$errorMessage = null;
$insightError = null;
$dashboardData = [
    'generated_at' => date('Y-m-d H:i:s'),
    'latest_reading' => null,
    'summary' => [
        'total_readings' => 0,
        'avg_temperature' => null,
        'avg_humidity' => null,
        'max_temperature' => null,
        'min_temperature' => null,
    ],
    'recent_readings' => [],
    'chart' => [
        'labels' => [],
        'temperatures' => [],
        'humidities' => [],
    ],
];
$insightData = readInsightCache($insightCacheFile);

try {
    $dashboardData = loadDashboardData($databaseFile);
    if ($insightData === null) {
        $insightData = getInsight($insightCacheFile, $ollamaUrl, $ollamaModel, $dashboardData, false);
    }
} catch (Throwable $exception) {
    $errorMessage = $exception->getMessage();
}

$latestReading = $dashboardData['latest_reading'];
$summary = $dashboardData['summary'];
$recentReadings = $dashboardData['recent_readings'];
$chart = $dashboardData['chart'];
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ESP32 DHT11 Dashboard</title>
    <style>
        :root {
            --bg: #f3efe5;
            --panel: rgba(255, 252, 245, 0.82);
            --panel-strong: #fffaf0;
            --text: #1d2a33;
            --muted: #60707b;
            --line: rgba(29, 42, 51, 0.12);
            --accent: #cc5a2e;
            --secondary: #1e7f78;
            --ai: #234f95;
            --shadow: 0 24px 60px rgba(78, 53, 27, 0.14);
        }

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
            color: var(--text);
            background:
                radial-gradient(circle at top left, rgba(204, 90, 46, 0.22), transparent 28%),
                radial-gradient(circle at top right, rgba(30, 127, 120, 0.18), transparent 30%),
                linear-gradient(180deg, #fbf7ef 0%, #eef4f2 100%);
            min-height: 100vh;
        }

        .shell {
            width: min(1180px, calc(100% - 32px));
            margin: 0 auto;
            padding: 32px 0 48px;
        }

        .hero {
            display: grid;
            grid-template-columns: 1.4fr 1fr;
            gap: 20px;
            margin-bottom: 20px;
        }

        .panel {
            background: var(--panel);
            border: 1px solid rgba(255, 255, 255, 0.6);
            border-radius: 24px;
            box-shadow: var(--shadow);
            backdrop-filter: blur(10px);
        }

        .hero-main {
            padding: 28px;
        }

        .eyebrow {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 8px 12px;
            border-radius: 999px;
            background: rgba(255, 255, 255, 0.55);
            color: var(--muted);
            font-size: 13px;
            letter-spacing: 0.04em;
            text-transform: uppercase;
        }

        h1 {
            margin: 18px 0 10px;
            font-size: clamp(30px, 4vw, 52px);
            line-height: 1;
        }

        .lead {
            margin: 0;
            max-width: 54ch;
            color: var(--muted);
            font-size: 16px;
            line-height: 1.6;
        }

        .hero-side {
            padding: 24px;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            gap: 18px;
        }

        .time-label {
            color: var(--muted);
            font-size: 14px;
        }

        .time-value {
            font-size: 32px;
            font-weight: 700;
        }

        .meta-chip {
            display: inline-flex;
            padding: 10px 14px;
            border-radius: 16px;
            background: var(--panel-strong);
            border: 1px solid var(--line);
            color: var(--text);
            font-size: 14px;
        }

        .stats {
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 16px;
            margin-bottom: 20px;
        }

        .stat-card {
            padding: 22px;
        }

        .stat-title {
            color: var(--muted);
            font-size: 14px;
            margin-bottom: 10px;
        }

        .stat-value {
            font-size: clamp(28px, 3vw, 38px);
            font-weight: 700;
            line-height: 1;
        }

        .accent {
            color: var(--accent);
        }

        .secondary {
            color: var(--secondary);
        }

        .insight-panel {
            padding: 24px;
            margin-bottom: 20px;
            border: 1px solid rgba(35, 79, 149, 0.18);
            background:
                linear-gradient(135deg, rgba(35, 79, 149, 0.10), rgba(255, 255, 255, 0.78)),
                var(--panel);
        }

        .insight-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 12px;
            margin-bottom: 12px;
        }

        .insight-title {
            margin: 0;
            font-size: 22px;
        }

        .insight-meta {
            color: var(--muted);
            font-size: 14px;
        }

        .insight-text {
            margin: 0;
            color: var(--text);
            font-size: 16px;
            line-height: 1.7;
            white-space: pre-wrap;
        }

        .button {
            border: none;
            border-radius: 14px;
            padding: 10px 14px;
            background: var(--ai);
            color: #fff;
            font-size: 14px;
            cursor: pointer;
        }

        .button:disabled {
            opacity: 0.6;
            cursor: wait;
        }

        .content {
            display: grid;
            grid-template-columns: 1.2fr 0.8fr;
            gap: 20px;
        }

        .chart-panel,
        .table-panel {
            padding: 24px;
        }

        .section-title {
            margin: 0 0 6px;
            font-size: 22px;
        }

        .section-subtitle {
            margin: 0 0 18px;
            color: var(--muted);
            font-size: 14px;
        }

        .chart-wrap {
            background: linear-gradient(180deg, rgba(255, 255, 255, 0.72), rgba(255, 255, 255, 0.45));
            border: 1px solid var(--line);
            border-radius: 22px;
            padding: 18px;
        }

        canvas {
            width: 100%;
            height: 320px;
            display: block;
        }

        .legend {
            display: flex;
            gap: 14px;
            margin-top: 12px;
            color: var(--muted);
            font-size: 14px;
        }

        .legend span {
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }

        .legend i {
            width: 12px;
            height: 12px;
            border-radius: 999px;
            display: inline-block;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            overflow: hidden;
            border-radius: 18px;
            background: rgba(255, 255, 255, 0.55);
        }

        th,
        td {
            padding: 14px 16px;
            text-align: left;
            border-bottom: 1px solid var(--line);
            font-size: 14px;
        }

        th {
            color: var(--muted);
            font-weight: 600;
            background: rgba(255, 255, 255, 0.65);
        }

        tr:last-child td {
            border-bottom: none;
        }

        .empty,
        .error {
            padding: 20px;
            border-radius: 20px;
            font-size: 15px;
        }

        .empty {
            background: rgba(255, 255, 255, 0.6);
            border: 1px dashed var(--line);
            color: var(--muted);
        }

        .error {
            background: #fff2ef;
            border: 1px solid #f3c7bd;
            color: #9f3d1d;
        }

        .status-row {
            margin-top: 20px;
            display: flex;
            justify-content: space-between;
            gap: 16px;
            color: var(--muted);
            font-size: 14px;
        }

        @media (max-width: 940px) {
            .hero,
            .content,
            .stats {
                grid-template-columns: 1fr;
            }

            .insight-header,
            .status-row {
                flex-direction: column;
                align-items: flex-start;
            }

            .shell {
                width: min(100% - 24px, 1180px);
                padding-top: 20px;
            }
        }
    </style>
</head>
<body>
    <div class="shell">
        <section class="hero">
            <div class="panel hero-main">
                <div class="eyebrow">ESP32 Climate Monitor</div>
                <h1>DHT11 Sensor Dashboard</h1>
                <p class="lead">
                    Live view for temperature and humidity readings stored in SQLite.
                    The dashboard updates every 5 seconds, and Ollama adds short insights using the local `llama3.2:1b` model.
                </p>
            </div>

            <aside class="panel hero-side">
                <div>
                    <div class="time-label">Current Malaysia time</div>
                    <div class="time-value" id="currentTime"><?= htmlspecialchars(date('Y-m-d H:i:s')) ?></div>
                </div>
                <div class="meta-chip" id="latestDeviceChip">
                    Latest device:
                    <?= htmlspecialchars((string) ($latestReading['device'] ?? 'No device yet')) ?>
                </div>
                <div class="meta-chip">
                    Model:
                    <?= htmlspecialchars($ollamaModel) ?>
                </div>
            </aside>
        </section>

        <div class="error panel" id="errorBox"<?= $errorMessage === null ? ' style="display:none;"' : '' ?>>
            <?= htmlspecialchars((string) $errorMessage) ?>
        </div>

        <div id="dashboardContent"<?= $errorMessage !== null ? ' style="display:none;"' : '' ?>>
            <section class="panel insight-panel">
                <div class="insight-header">
                    <div>
                        <h2 class="insight-title">AI Insight</h2>
                        <div class="insight-meta" id="insightMeta">
                            <?= $insightData !== null && isset($insightData['generated_at'])
                                ? htmlspecialchars('Generated at ' . $insightData['generated_at'] . ' by ' . ($insightData['model'] ?? $ollamaModel))
                                : 'No insight generated yet.' ?>
                        </div>
                    </div>
                    <button class="button" id="refreshInsightButton" type="button">Refresh Insight</button>
                </div>
                <p class="insight-text" id="insightText">
                    <?= htmlspecialchars((string) ($insightData['insight'] ?? 'Insight will appear here after the first analysis.')) ?>
                </p>
            </section>

            <section class="stats">
                <div class="panel stat-card">
                    <div class="stat-title">Latest Temperature</div>
                    <div class="stat-value accent" id="latestTemperature">
                        <?= $latestReading ? htmlspecialchars(formatNumber($latestReading['temperature'])) . ' &deg;C' : '--' ?>
                    </div>
                </div>
                <div class="panel stat-card">
                    <div class="stat-title">Latest Humidity</div>
                    <div class="stat-value secondary" id="latestHumidity">
                        <?= $latestReading ? htmlspecialchars(formatNumber($latestReading['humidity'])) . ' %' : '--' ?>
                    </div>
                </div>
                <div class="panel stat-card">
                    <div class="stat-title">Average Temperature</div>
                    <div class="stat-value" id="avgTemperature">
                        <?= htmlspecialchars(formatNumber($summary['avg_temperature'])) ?> &deg;C
                    </div>
                </div>
                <div class="panel stat-card">
                    <div class="stat-title">Total Readings</div>
                    <div class="stat-value" id="totalReadings">
                        <?= htmlspecialchars(number_format((int) $summary['total_readings'])) ?>
                    </div>
                </div>
            </section>

            <section class="content">
                <div class="panel chart-panel">
                    <h2 class="section-title">Recent Trend</h2>
                    <p class="section-subtitle">Last 12 readings for temperature and humidity.</p>

                    <div class="empty" id="chartEmpty"<?= $chart['labels'] !== [] ? ' style="display:none;"' : '' ?>>
                        No chart data yet. Send a few readings from the ESP32 to populate the graph.
                    </div>

                    <div class="chart-wrap" id="chartWrap"<?= $chart['labels'] === [] ? ' style="display:none;"' : '' ?>>
                        <canvas id="sensorChart" width="720" height="320"></canvas>
                        <div class="legend">
                            <span><i style="background:#cc5a2e"></i>Temperature</span>
                            <span><i style="background:#1e7f78"></i>Humidity</span>
                        </div>
                    </div>
                </div>

                <div class="panel table-panel">
                    <h2 class="section-title">Reading Summary</h2>
                    <p class="section-subtitle">Range and average across all saved data.</p>
                    <table>
                        <tbody>
                            <tr>
                                <th>Average humidity</th>
                                <td id="avgHumidity"><?= htmlspecialchars(formatNumber($summary['avg_humidity'])) ?> %</td>
                            </tr>
                            <tr>
                                <th>Highest temperature</th>
                                <td id="maxTemperature"><?= htmlspecialchars(formatNumber($summary['max_temperature'])) ?> &deg;C</td>
                            </tr>
                            <tr>
                                <th>Lowest temperature</th>
                                <td id="minTemperature"><?= htmlspecialchars(formatNumber($summary['min_temperature'])) ?> &deg;C</td>
                            </tr>
                            <tr>
                                <th>Last update</th>
                                <td id="lastUpdate"><?= htmlspecialchars((string) ($latestReading['created_at'] ?? '--')) ?></td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </section>

            <section class="panel table-panel" style="margin-top:20px;">
                <h2 class="section-title">Recent Readings</h2>
                <p class="section-subtitle">Newest 20 rows from the SQLite database.</p>

                <div class="empty" id="tableEmpty"<?= $recentReadings !== [] ? ' style="display:none;"' : '' ?>>
                    No readings saved yet.
                </div>

                <div style="overflow:auto;<?= $recentReadings === [] ? ' display:none;' : '' ?>" id="tableWrap">
                    <table>
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Device</th>
                                <th>Temperature</th>
                                <th>Humidity</th>
                                <th>Created At</th>
                            </tr>
                        </thead>
                        <tbody id="recentReadingsBody">
                            <?php foreach ($recentReadings as $row): ?>
                                <tr>
                                    <td><?= htmlspecialchars((string) $row['id']) ?></td>
                                    <td><?= htmlspecialchars((string) ($row['device'] ?: '-')) ?></td>
                                    <td><?= htmlspecialchars(formatNumber($row['temperature'])) ?> &deg;C</td>
                                    <td><?= htmlspecialchars(formatNumber($row['humidity'])) ?> %</td>
                                    <td><?= htmlspecialchars((string) $row['created_at']) ?></td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </section>

            <div class="status-row">
                <div>Data refresh: every 5 seconds</div>
                <div id="syncStatus">Last sync: <?= htmlspecialchars($dashboardData['generated_at']) ?></div>
            </div>
        </div>
    </div>

    <script>
        const chartState = {
            labels: <?= json_encode($chart['labels'], JSON_UNESCAPED_SLASHES) ?>,
            temperatures: <?= json_encode($chart['temperatures'], JSON_UNESCAPED_SLASHES) ?>,
            humidities: <?= json_encode($chart['humidities'], JSON_UNESCAPED_SLASHES) ?>
        };

        function escapeHtml(value) {
            return String(value).replace(/[&<>"']/g, function(character) {
                const entities = {
                    '&': '&amp;',
                    '<': '&lt;',
                    '>': '&gt;',
                    '"': '&quot;',
                    "'": '&#039;'
                };
                return entities[character];
            });
        }

        function formatNumber(value) {
            const numericValue = Number(value);
            if (Number.isNaN(numericValue)) {
                return '--';
            }
            return numericValue.toFixed(1);
        }

        function drawChart() {
            const canvas = document.getElementById('sensorChart');
            if (!canvas) {
                return;
            }

            const labels = chartState.labels;
            const temperatures = chartState.temperatures;
            const humidities = chartState.humidities;
            const chartWrap = document.getElementById('chartWrap');
            const chartEmpty = document.getElementById('chartEmpty');

            if (labels.length === 0) {
                chartWrap.style.display = 'none';
                chartEmpty.style.display = 'block';
                return;
            }

            chartWrap.style.display = 'block';
            chartEmpty.style.display = 'none';

            const ctx = canvas.getContext('2d');
            const width = canvas.width;
            const height = canvas.height;
            const padding = { top: 24, right: 18, bottom: 34, left: 34 };
            const chartWidth = width - padding.left - padding.right;
            const chartHeight = height - padding.top - padding.bottom;

            ctx.clearRect(0, 0, width, height);

            const allValues = temperatures.concat(humidities);
            const minValue = Math.min.apply(null, allValues) - 2;
            const maxValue = Math.max.apply(null, allValues) + 2;

            function yScale(value) {
                return padding.top + chartHeight - ((value - minValue) / (maxValue - minValue || 1)) * chartHeight;
            }

            function xScale(index) {
                if (labels.length === 1) {
                    return padding.left + chartWidth / 2;
                }
                return padding.left + (index / (labels.length - 1)) * chartWidth;
            }

            ctx.strokeStyle = 'rgba(29, 42, 51, 0.12)';
            ctx.lineWidth = 1;
            ctx.font = '12px Segoe UI';
            ctx.fillStyle = '#60707b';

            for (let i = 0; i <= 4; i++) {
                const value = minValue + ((maxValue - minValue) / 4) * i;
                const y = padding.top + chartHeight - (chartHeight / 4) * i;
                ctx.beginPath();
                ctx.moveTo(padding.left, y);
                ctx.lineTo(width - padding.right, y);
                ctx.stroke();
                ctx.fillText(value.toFixed(1), 4, y + 4);
            }

            labels.forEach(function(label, index) {
                const x = xScale(index);
                ctx.fillText(label, x - 16, height - 10);
            });

            function drawLine(values, color, fillColor) {
                ctx.beginPath();
                values.forEach(function(value, index) {
                    const x = xScale(index);
                    const y = yScale(value);
                    if (index === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                });

                ctx.strokeStyle = color;
                ctx.lineWidth = 3;
                ctx.stroke();

                ctx.lineTo(xScale(values.length - 1), padding.top + chartHeight);
                ctx.lineTo(xScale(0), padding.top + chartHeight);
                ctx.closePath();
                ctx.fillStyle = fillColor;
                ctx.fill();

                values.forEach(function(value, index) {
                    const x = xScale(index);
                    const y = yScale(value);
                    ctx.beginPath();
                    ctx.arc(x, y, 4, 0, Math.PI * 2);
                    ctx.fillStyle = color;
                    ctx.fill();
                });
            }

            drawLine(temperatures, '#cc5a2e', 'rgba(204, 90, 46, 0.14)');
            drawLine(humidities, '#1e7f78', 'rgba(30, 127, 120, 0.10)');
        }

        function renderDashboard(data) {
            const latest = data.latest_reading;
            const summary = data.summary;
            const recentReadings = data.recent_readings;
            const chart = data.chart;

            document.getElementById('errorBox').style.display = 'none';
            document.getElementById('dashboardContent').style.display = 'block';
            document.getElementById('currentTime').textContent = data.generated_at;
            document.getElementById('latestDeviceChip').textContent = 'Latest device: ' + (latest && latest.device ? latest.device : 'No device yet');
            document.getElementById('latestTemperature').innerHTML = latest ? escapeHtml(formatNumber(latest.temperature)) + ' &deg;C' : '--';
            document.getElementById('latestHumidity').innerHTML = latest ? escapeHtml(formatNumber(latest.humidity)) + ' %' : '--';
            document.getElementById('avgTemperature').innerHTML = escapeHtml(formatNumber(summary.avg_temperature)) + ' &deg;C';
            document.getElementById('totalReadings').textContent = Number(summary.total_readings || 0).toLocaleString();
            document.getElementById('avgHumidity').innerHTML = escapeHtml(formatNumber(summary.avg_humidity)) + ' %';
            document.getElementById('maxTemperature').innerHTML = escapeHtml(formatNumber(summary.max_temperature)) + ' &deg;C';
            document.getElementById('minTemperature').innerHTML = escapeHtml(formatNumber(summary.min_temperature)) + ' &deg;C';
            document.getElementById('lastUpdate').textContent = latest && latest.created_at ? latest.created_at : '--';
            document.getElementById('syncStatus').textContent = 'Last sync: ' + data.generated_at;

            const tbody = document.getElementById('recentReadingsBody');
            const tableWrap = document.getElementById('tableWrap');
            const tableEmpty = document.getElementById('tableEmpty');

            if (!recentReadings.length) {
                tbody.innerHTML = '';
                tableWrap.style.display = 'none';
                tableEmpty.style.display = 'block';
            } else {
                tableEmpty.style.display = 'none';
                tableWrap.style.display = 'block';
                tbody.innerHTML = recentReadings.map(function(row) {
                    return '<tr>' +
                        '<td>' + escapeHtml(row.id) + '</td>' +
                        '<td>' + escapeHtml(row.device || '-') + '</td>' +
                        '<td>' + escapeHtml(formatNumber(row.temperature)) + ' &deg;C</td>' +
                        '<td>' + escapeHtml(formatNumber(row.humidity)) + ' %</td>' +
                        '<td>' + escapeHtml(row.created_at) + '</td>' +
                    '</tr>';
                }).join('');
            }

            chartState.labels = chart.labels || [];
            chartState.temperatures = chart.temperatures || [];
            chartState.humidities = chart.humidities || [];
            drawChart();
        }

        function renderInsight(data) {
            document.getElementById('insightText').textContent = data.insight || 'No insight available.';
            document.getElementById('insightMeta').textContent = 'Generated at ' + data.generated_at + ' by ' + data.model;
        }

        async function refreshDashboard() {
            try {
                const response = await fetch('index.php?format=json', {
                    cache: 'no-store',
                    headers: {
                        'Accept': 'application/json'
                    }
                });

                const payload = await response.json();
                if (!response.ok || !payload.success) {
                    throw new Error(payload.message || 'Failed to load dashboard data.');
                }

                renderDashboard(payload.data);
            } catch (error) {
                const errorBox = document.getElementById('errorBox');
                errorBox.textContent = error.message;
                errorBox.style.display = 'block';
            }
        }

        async function refreshInsight(forceRefresh) {
            const button = document.getElementById('refreshInsightButton');

            try {
                button.disabled = true;
                button.textContent = 'Generating...';

                const url = 'index.php?format=insight' + (forceRefresh ? '&refresh=1' : '');
                const response = await fetch(url, {
                    cache: 'no-store',
                    headers: {
                        'Accept': 'application/json'
                    }
                });

                const payload = await response.json();
                if (!response.ok || !payload.success) {
                    throw new Error(payload.message || 'Failed to load AI insight.');
                }

                renderInsight(payload.data);
            } catch (error) {
                document.getElementById('insightText').textContent = error.message;
            } finally {
                button.disabled = false;
                button.textContent = 'Refresh Insight';
            }
        }

        document.getElementById('refreshInsightButton').addEventListener('click', function() {
            refreshInsight(true);
        });

        drawChart();
        setInterval(refreshDashboard, 5000);
        setInterval(function() {
            refreshInsight(false);
        }, 60000);
    </script>
</body>
</html>
