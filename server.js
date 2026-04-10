const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const mqtt = require("mqtt");
const https = require("https");

const app = express();
app.use(express.json());
app.use(cors());

// ─── Global Logger ────────────────────────────────────────────────────────────
app.use((req, res, next) => {
    console.log(`\n[${new Date().toLocaleTimeString()}] 🌐 ${req.method} ${req.url}`);
    if (req.method === 'POST' || req.method === 'PUT') {
        console.log("📦 Payload:", JSON.stringify(req.body));
    }
    next();
});

// ─── Health Checks ────────────────────────────────────────────────────────────
app.get("/", (req, res) => res.send("Smart Irrigation Server — ALIVE ✅"));
app.get("/ping", (req, res) => res.send("pong"));

// ─── MongoDB ──────────────────────────────────────────────────────────────────
const MONGODB_URI = "mongodb+srv://karthik7133:Ch.karthik.7@cluster7133.yzxk6k4.mongodb.net/irrigation";

mongoose.connect(MONGODB_URI)
    .then(() => console.log("✅ [DB] Connected to MongoDB Atlas"))
    .catch(err => console.error("❌ [DB] Fatal connection error:", err));

mongoose.connection.on('error', err => console.error("❌ [DB] Runtime error:", err));
mongoose.connection.on('disconnected', () => console.log("⚠️ [DB] Mongoose disconnected"));

// ─── Schemas ──────────────────────────────────────────────────────────────────

// Zone progress snapshot saved periodically
const ZoneLogSchema = new mongoose.Schema({
    zone1Progress: { type: Number, default: 0 },
    zone2Progress: { type: Number, default: 0 },
    precipitation:  { type: Number, default: 0 },
    gatesOpen:      { type: Boolean, default: true },
    time:           { type: Date, default: Date.now }
}, { collection: 'zone_logs' });

const ZoneLog = mongoose.model("ZoneLog", ZoneLogSchema);

// Settings (location, crop type etc.) — written by the Flutter app
const SettingsSchema = new mongoose.Schema({
    projectName: { type: String, default: "Smart Irrigation" },
    latitude:    Number,
    longitude:   Number,
    cropType:    String,
    minMoisture: Number,
    maxMoisture: Number,
    lastUpdated: { type: Date, default: Date.now }
}, { collection: 'settings' });

const Settings = mongoose.model("Settings", SettingsSchema);

// ─── In-Memory State ─────────────────────────────────────────────────────────
const liveState = {
    zone1: { progress: 0, updatedAt: null },
    zone2: { progress: 0, updatedAt: null },
    precipitation: 0,
    precipUpdatedAt: null,
    gatesOpen: true,
};

// ─── MQTT Client ─────────────────────────────────────────────────────────────
const MQTT_BROKER = "mqtt://broker.hivemq.com";
const TOPIC_ZONE1  = "smartfarm/zone1/progress";
const TOPIC_ZONE2  = "smartfarm/zone2/progress";
const TOPIC_CTRL   = "smartfarm/control";

let mqttClient = null;

function connectMQTT() {
    console.log("🔌 [MQTT] Connecting to", MQTT_BROKER, "...");

    mqttClient = mqtt.connect(MQTT_BROKER, {
        clientId: `smart-irrigation-server-${Math.random().toString(16).slice(2, 8)}`,
        clean: true,
        connectTimeout: 10_000,
        reconnectPeriod: 5_000,   // auto-reconnect every 5 s on drop
        keepalive: 60,
    });

    mqttClient.on("connect", () => {
        console.log("✅ [MQTT] Connected to HiveMQ broker");
        mqttClient.subscribe([TOPIC_ZONE1, TOPIC_ZONE2], { qos: 1 }, (err) => {
            if (err) {
                console.error("❌ [MQTT] Subscription error:", err.message);
            } else {
                console.log(`📡 [MQTT] Subscribed to ${TOPIC_ZONE1} and ${TOPIC_ZONE2}`);
            }
        });
    });

    mqttClient.on("message", (topic, payload) => {
        try {
            const data = JSON.parse(payload.toString());
            console.log(`📨 [MQTT] Message on ${topic}:`, data);

            if (topic === TOPIC_ZONE1) {
                liveState.zone1.progress  = Number(data.progress ?? data.value ?? 0);
                liveState.zone1.updatedAt = new Date();
            } else if (topic === TOPIC_ZONE2) {
                liveState.zone2.progress  = Number(data.progress ?? data.value ?? 0);
                liveState.zone2.updatedAt = new Date();
            }
        } catch (e) {
            console.error("❌ [MQTT] Failed to parse message:", e.message, "| raw:", payload.toString());
        }
    });

    mqttClient.on("reconnect", () => console.log("🔄 [MQTT] Reconnecting..."));
    mqttClient.on("offline",   () => console.log("⚠️  [MQTT] Client offline"));
    mqttClient.on("error",  err => console.error("❌ [MQTT] Error:", err.message));
}

// Publish a control command to all gates
function publishGateCommand(open) {
    if (!mqttClient || !mqttClient.connected) {
        console.error("❌ [MQTT] Cannot publish — client not connected");
        return;
    }
    const payload = JSON.stringify({ command: open ? "OPEN" : "CLOSE", timestamp: Date.now() });
    mqttClient.publish(TOPIC_CTRL, payload, { qos: 1, retain: true }, (err) => {
        if (err) {
            console.error("❌ [MQTT] Publish error:", err.message);
        } else {
            console.log(`📤 [MQTT] Gate command sent → ${open ? "OPEN" : "CLOSE"}`);
        }
    });
    liveState.gatesOpen = open;
}

// ─── Weather "Smart Brain" ────────────────────────────────────────────────────
const WEATHER_INTERVAL_MS = 5 * 60 * 1000; // every 5 minutes
const RAIN_THRESHOLD       = 80;            // % precipitation probability

async function fetchPrecipitation(lat, lon) {
    return new Promise((resolve, reject) => {
        const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&hourly=precipitation_probability&forecast_days=1&timezone=auto`;
        https.get(url, (res) => {
            let raw = "";
            res.on("data", chunk => (raw += chunk));
            res.on("end", () => {
                try {
                    const json = JSON.parse(raw);
                    // Get the current hour's precipitation probability
                    const hourlyProbs = json?.hourly?.precipitation_probability ?? [];
                    const currentHour = new Date().getHours();
                    const prob = hourlyProbs[currentHour] ?? hourlyProbs[0] ?? 0;
                    resolve(Number(prob));
                } catch (e) {
                    reject(new Error(`Weather API parse error: ${e.message}`));
                }
            });
        }).on("error", reject);
    });
}

async function runWeatherBrain() {
    try {
        const settings = await Settings.findOne().lean();
        const lat = settings?.latitude  ?? 16.3;
        const lon = settings?.longitude ?? 80.4;

        console.log(`\n🌦  [Brain] Fetching weather for (${lat}, ${lon})...`);
        const precipitation = await fetchPrecipitation(lat, lon);

        liveState.precipitation   = precipitation;
        liveState.precipUpdatedAt = new Date();
        console.log(`🌧  [Brain] Precipitation probability: ${precipitation}%`);

        if (precipitation > RAIN_THRESHOLD) {
            console.log(`🚫 [Brain] Rain likely (${precipitation}% > ${RAIN_THRESHOLD}%) → CLOSING all gates`);
            publishGateCommand(false); // CLOSE / STOP
        } else {
            console.log(`✅ [Brain] Rain unlikely (${precipitation}% ≤ ${RAIN_THRESHOLD}%) → Gates OPEN`);
            publishGateCommand(true);  // OPEN / proceed
        }

        // Persist a snapshot to MongoDB
        await new ZoneLog({
            zone1Progress: liveState.zone1.progress,
            zone2Progress: liveState.zone2.progress,
            precipitation,
            gatesOpen: liveState.gatesOpen,
        }).save();
        console.log("💾 [Brain] Snapshot saved to MongoDB");

    } catch (err) {
        console.error("❌ [Brain] Error in weather brain loop:", err.message);
    }
}

// ─── REST API ─────────────────────────────────────────────────────────────────

// GET /live-zones — Flutter app polls this every 3 seconds
app.get("/live-zones", (req, res) => {
    res.json({
        zone1: {
            progress: liveState.zone1.progress,
            updatedAt: liveState.zone1.updatedAt,
        },
        zone2: {
            progress: liveState.zone2.progress,
            updatedAt: liveState.zone2.updatedAt,
        },
        precipitation:    liveState.precipitation,
        precipUpdatedAt:  liveState.precipUpdatedAt,
        gatesOpen:        liveState.gatesOpen,
        rainThreshold:    RAIN_THRESHOLD,
    });
});

// POST /settings — Flutter app saves location & crop
app.post("/settings", async (req, res) => {
    try {
        let settings = await Settings.findOne();
        if (!settings) settings = new Settings();

        const { latitude, longitude, cropType, projectName } = req.body;

        if (latitude    !== undefined) settings.latitude    = latitude;
        if (longitude   !== undefined) settings.longitude   = longitude;
        if (projectName !== undefined) settings.projectName = projectName;

        if (cropType !== undefined) {
            settings.cropType = cropType;
            const thresholds = {
                Rice:   { min: 60, max: 80 },
                Tomato: { min: 40, max: 60 },
                Cotton: { min: 30, max: 50 },
            };
            const t = thresholds[cropType] ?? { min: 40, max: 70 };
            settings.minMoisture = t.min;
            settings.maxMoisture = t.max;
        }

        settings.lastUpdated = Date.now();
        await settings.save();
        console.log("✅ [DB] Settings updated");
        res.json({ message: "Settings Updated", settings });
    } catch (err) {
        console.error("❌ [POST /settings]", err.message);
        res.status(500).json({ error: err.message });
    }
});

// GET /settings — for internal use / app config fetch
app.get("/settings", async (req, res) => {
    try {
        const settings = await Settings.findOne();
        if (!settings) {
            return res.json({ latitude: 16.3, longitude: 80.4, minMoisture: 40, maxMoisture: 70 });
        }
        res.json(settings);
    } catch (err) {
        console.error("❌ [GET /settings]", err.message);
        res.status(500).json({ error: err.message });
    }
});

// GET /history — last 50 zone log snapshots
app.get("/history", async (req, res) => {
    try {
        const logs = await ZoneLog.find().sort({ time: -1 }).limit(50).lean();
        res.json(logs.reverse());
    } catch (err) {
        console.error("❌ [GET /history]", err.message);
        res.status(500).json({ error: err.message });
    }
});

// ─── Bootstrap ────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () => {
    console.log(`\n🚀 Server running on port ${PORT}`);
    connectMQTT();

    // Run weather brain immediately, then on interval
    setTimeout(runWeatherBrain, 3000);
    setInterval(runWeatherBrain, WEATHER_INTERVAL_MS);
});
