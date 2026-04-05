from flask import Flask, request, jsonify
import sqlite3
from datetime import datetime
import requests

app = Flask(__name__)

DB_NAME = "database.db"

# =========================
# INIT DATABASE (SAFE)
# =========================
def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    # Create table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS sensor_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        temperature REAL,
        humidity REAL,
        timestamp TEXT
    )
    """)

    # Check column 'analysis'
    cursor.execute("PRAGMA table_info(sensor_data)")
    columns = [col[1] for col in cursor.fetchall()]

    if "analysis" not in columns:
        cursor.execute("ALTER TABLE sensor_data ADD COLUMN analysis TEXT")

    conn.commit()
    conn.close()

init_db()

# =========================
# CALL OLLAMA (FIXED)
# =========================
def call_llm(temp, hum):
    prompt = f"""
You are an IoT smart assistant for a polytechnic lab.

Temperature: {temp}°C
Humidity: {hum}%

1. Explain condition
2. State if comfortable or not
3. Give short action
Keep it concise (max 1 sentences).
"""

    try:
        response = requests.post(
            "http://192.168.137.1:11434/api/chat",
            json={
                "model": "qwen3:4b",
                "messages": [
                    {"role": "user", "content": prompt}
                ],
                "stream": False,
                "options": {
                    "num_predict": 60   # 🔥 limit panjang output
                }
            },
            timeout=30
        )

        data = response.json()

        content = data["message"]["content"]

        # 🔥 REMOVE THINKING STYLE OUTPUT
        content = content.split("**thinking**")[0]  # safety
        content = content.strip()

        return content

    except Exception as e:
        return f"LLM Error: {str(e)}"

# =========================
# MAIN API (ESP32)
# =========================
@app.route('/api/data', methods=['POST'])
def receive_data():
    data = request.json

    temp = data.get('temperature')
    hum = data.get('humidity')

    if temp is None or hum is None:
        return jsonify({"status": "error", "message": "Invalid data"}), 400

    # CALL AI
    analysis = call_llm(temp, hum)

    # SAVE TO DB
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO sensor_data (temperature, humidity, analysis, timestamp)
        VALUES (?, ?, ?, ?)
    """, (temp, hum, analysis, datetime.now().isoformat()))

    conn.commit()
    conn.close()

    return jsonify({
        "status": "success",
        "temperature": temp,
        "humidity": hum,
        "analysis": analysis
    })

# =========================
# TEST LLM ONLY
# =========================
@app.route('/test-llm')
def test_llm():
    return call_llm(30, 70)

# =========================
# VIEW DATA
# =========================
@app.route('/data')
def view_data():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, temperature, humidity, analysis, timestamp
        FROM sensor_data
        ORDER BY id DESC
        LIMIT 10
    """)

    rows = cursor.fetchall()
    conn.close()

    return jsonify(rows)

@app.route('/dashboard')
def dashboard():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>AIoT Dashboard</title>
        <meta http-equiv="refresh" content="5">
        <style>
            body {
                font-family: Arial;
                background: #f4f6f8;
                text-align: center;
            }
            .card {
                background: white;
                padding: 20px;
                margin: 20px auto;
                width: 60%;
                border-radius: 10px;
                box-shadow: 0 4px 10px rgba(0,0,0,0.1);
            }
            h1 {
                color: #2c3e50;
            }
            .value {
                font-size: 28px;
                font-weight: bold;
            }
            .analysis {
                margin-top: 10px;
                color: #555;
                font-style: italic;
            }
        </style>
    </head>
    <body>

        <h1>📡 AIoT Dashboard</h1>

        <div id="content"></div>

        <script>
            async function loadData() {
                const res = await fetch('/data');
                const data = await res.json();

                let html = "";

                data.forEach(row => {
                    html += `
                        <div class="card">
                            <div class="value">🌡 ${row[1]} °C</div>
                            <div class="value">💧 ${row[2]} %</div>
                            <div class="analysis">🤖 ${row[3]}</div>
                        </div>
                    `;
                });

                document.getElementById("content").innerHTML = html;
            }

            loadData();
            setInterval(loadData, 5000);
        </script>

    </body>
    </html>
    """
    
# =========================
# HOME
# =========================
@app.route('/')
def home():
    return "Flask + ESP32 + SQLite + Ollama Running 🚀"

# =========================
# RUN
# =========================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)