const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");

const app = express();
app.use(express.json());
app.use(cors());

// 1. Enhanced Global Logger
app.use((req, res, next) => {
    console.log(`\n[${new Date().toLocaleTimeString()}] 🌐 ${req.method} ${req.url}`);
    if (req.method === 'POST' || req.method === 'PUT') {
        console.log("📦 Payload:", JSON.stringify(req.body));
    }
    next();
});

// Health check
app.get("/", (req, res) => res.send("Server is ALIVE"));
app.get("/ping", (req, res) => res.send("pong"));

const MONGODB_URI = "mongodb+srv://karthik7133:Ch.karthik.7@cluster7133.yzxk6k4.mongodb.net/irrigation";

// 2. Enhanced MongoDB Connection Debugging
mongoose.connect(MONGODB_URI)
    .then(() => console.log("✅ [DB] Successfully connected to MongoDB Atlas"))
    .catch(err => console.error("❌ [DB] FATAL MongoDB Connection Error:", err));

// Monitor DB connection drops while the server is running
mongoose.connection.on('error', err => {
    console.error("❌ [DB] Mongoose runtime connection error:", err);
});
mongoose.connection.on('disconnected', () => {
    console.log("⚠️ [DB] Mongoose disconnected from Atlas");
});

// Schema for Sensor Data
const DataSchema = new mongoose.Schema({
    temperature: Number,
    humidity: Number,
    moisture: Number,
    precipitation: Number,
    motorStatus: String,
    savedWater: Number,
    batteryLevel: Number,
    diseaseRisk: String,
    time: { type: Date, default: Date.now }
}, { collection: 'data' });

const Data = mongoose.model("Data", DataSchema);

// Schema for User Settings & ESP32 Config
const SettingsSchema = new mongoose.Schema({
    projectName: { type: String, default: "Smart Irrigation" },
    latitude: Number,
    longitude: Number,
    cropType: String,
    minMoisture: Number,
    maxMoisture: Number,
    lastUpdated: { type: Date, default: Date.now }
}, { collection: 'settings' });

const Settings = mongoose.model("Settings", SettingsSchema);

// POST settings (from App)
app.post("/settings", async (req, res) => {
    try {
        let settings = await Settings.findOne();
        if (!settings) settings = new Settings(); // Create new if it doesn't exist

        const { latitude, longitude, cropType, projectName } = req.body;

        if (latitude !== undefined) settings.latitude = latitude;
        if (longitude !== undefined) settings.longitude = longitude;
        if (projectName !== undefined) settings.projectName = projectName;

        // Only update thresholds if a cropType was explicitly sent
        if (cropType !== undefined) {
            settings.cropType = cropType;
            if (cropType === "Rice") {
                settings.minMoisture = 60;
                settings.maxMoisture = 80;
            } else if (cropType === "Tomato") {
                settings.minMoisture = 40;
                settings.maxMoisture = 60;
            } else if (cropType === "Cotton") {
                settings.minMoisture = 30;
                settings.maxMoisture = 50;
            } else {
                settings.minMoisture = 40;
                settings.maxMoisture = 70;
            }
        }

        settings.lastUpdated = Date.now();
        await settings.save();
        console.log("✅ [DB] Settings updated successfully");
        res.json({ message: "Settings Updated", settings });
    } catch (err) {
        console.error("❌ [POST /settings] Error:", err.message);
        res.status(500).json({ error: err.message });
    }
});

// GET settings (for ESP32)
app.get("/settings", async (req, res) => {
    try {
        const settings = await Settings.findOne();
        if (!settings) {
            console.log("⚠️ [GET /settings] No settings found, sending defaults.");
            return res.json({
                latitude: 16.3,
                longitude: 80.4,
                minMoisture: 40,
                maxMoisture: 70
            });
        }
        console.log("📤 [GET /settings] Sending settings to ESP32");
        res.json(settings);
    } catch (err) {
        console.error("❌ [GET /settings] Error:", err.message);
        res.status(500).json({ error: err.message });
    }
});

// 3. Enhanced POST Data Debugging
app.post("/data", async (req, res) => {
    try {
        console.log("📥 [POST /data] Processing incoming sensor data...");
        const { temperature, humidity } = req.body;

        let diseaseRisk = "LOW";
        if (temperature && humidity && temperature > 25 && humidity > 80) {
            diseaseRisk = "HIGH";
        }

        const data = new Data({
            ...req.body,
            diseaseRisk
        });

        // Explicit validation check before saving
        const validationError = data.validateSync();
        if (validationError) {
            console.error("❌ [DB Validation Error]:", validationError.errors);
            return res.status(400).send("Validation Error");
        }

        const savedData = await data.save();
        console.log("✅ [DB] Data securely saved! Document ID:", savedData._id);
        res.status(201).send("Saved");
    } catch (err) {
        console.error("❌ [POST /data] Critical Error saving to DB:", err);
        res.status(500).send(err.message);
    }
});

// Latest data
app.get("/latest", async (req, res) => {
    try {
        const latest = await Data.findOne().sort({ time: -1 });
        if (!latest) {
            console.log("⚠️ [GET /latest] DB is empty.");
            return res.json({});
        }
        res.json(latest);
    } catch (err) {
        console.error("❌ [GET /latest] Error:", err.message);
        res.status(500).json({ error: err.message });
    }
});

// History for graphs
app.get("/history", async (req, res) => {
    try {
        const history = await Data.find().sort({ time: 1 });
        res.json(history);
    } catch (err) {
        console.error("❌ [GET /history] Error:", err.message);
        res.status(500).json({ error: err.message });
    }
});

// Water saving stats
app.get("/stats", async (req, res) => {
    try {
        const records = await Data.find();
        const total = records.length;

        const motorOffDueToRain = records.filter(
            r => r.motorStatus === "OFF" && r.precipitation > 80
        ).length;

        const saved = total === 0 ? 0 : (motorOffDueToRain / total) * 100;
        res.json({ waterSavedPercent: saved.toFixed(2) });
    } catch (err) {
        console.error("❌ [GET /stats] Error:", err.message);
        res.status(500).json({ error: err.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Server running on port ${PORT}`);
});
