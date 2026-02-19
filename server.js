const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");

const app = express();
app.use(express.json());
app.use(cors());

// Global Logger
app.use((req, res, next) => {
    console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
    next();
});

// Health check
app.get("/", (req, res) => res.send("Server is ALIVE"));
app.get("/ping", (req, res) => res.send("pong"));

mongoose.connect("mongodb+srv://karthik7133:Ch.karthik.7@cluster7133.yzxk6k4.mongodb.net/irrigation");

// Schema for Sensor Data
const DataSchema = new mongoose.Schema({
    temperature: Number,
    humidity: Number,
    moisture: Number,
    precipitation: Number,
    motorStatus: String,
    savedWater: Number,
    batteryLevel: Number,           // Added
    diseaseRisk: String,            // Added ("LOW" or "HIGH")
    time: { type: Date, default: Date.now }
});

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
});

const Settings = mongoose.model("Settings", SettingsSchema);

// POST settings (from App)
app.post("/settings", async (req, res) => {
    console.log("Settings update received:", req.body);
    const { latitude, longitude, cropType, projectName } = req.body;

    let minMoisture = 40;
    let maxMoisture = 70;

    // Crop Threshold Logic
    if (cropType === "Rice") {
        minMoisture = 60;
        maxMoisture = 80;
    } else if (cropType === "Tomato") {
        minMoisture = 40;
        maxMoisture = 60;
    } else if (cropType === "Cotton") {
        minMoisture = 30;
        maxMoisture = 50;
    }

    try {
        let settings = await Settings.findOne();
        if (!settings) settings = new Settings();

        if (latitude !== undefined) settings.latitude = latitude;
        if (longitude !== undefined) settings.longitude = longitude;
        if (cropType !== undefined) settings.cropType = cropType;
        if (projectName) settings.projectName = projectName;

        settings.minMoisture = minMoisture;
        settings.maxMoisture = maxMoisture;
        settings.lastUpdated = Date.now();

        await settings.save();
        res.json({ message: "Settings Updated", settings });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET settings (for ESP32)
app.get("/settings", async (req, res) => {
    const settings = await Settings.findOne();
    if (!settings) {
        return res.json({
            latitude: 16.3,
            longitude: 80.4,
            minMoisture: 40,
            maxMoisture: 70
        });
    }
    res.json(settings);
});

// POST data from ESP32
app.post("/data", async (req, res) => {
    console.log("Data received from ESP32:", req.body);

    const { temperature, humidity } = req.body;

    // Disease Risk Calculation
    // if temperature > 25 and humidity > 80, risk is "HIGH", else "LOW"
    let diseaseRisk = "LOW";
    if (temperature > 25 && humidity > 80) {
        diseaseRisk = "HIGH";
    }

    const data = new Data({
        ...req.body,
        diseaseRisk
    });

    try {
        await data.save();
        res.send("Saved");
    } catch (err) {
        res.status(500).send(err.message);
    }
});

// Latest data
app.get("/latest", async (req, res) => {
    const latest = await Data.findOne().sort({ time: -1 });
    res.json(latest);
});

// History for graphs
app.get("/history", async (req, res) => {
    const history = await Data.find().sort({ time: 1 });
    res.json(history);
});

// Water saving stats
app.get("/stats", async (req, res) => {
    const records = await Data.find();
    const total = records.length;

    const motorOffDueToRain = records.filter(
        r => r.motorStatus === "OFF" && r.precipitation > 80
    ).length;

    const saved = total === 0 ? 0 : (motorOffDueToRain / total) * 100;

    res.json({ waterSavedPercent: saved.toFixed(2) });
});

app.listen(3000, () => console.log("Server running on port 3000"));
