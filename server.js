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

// Schema
const DataSchema = new mongoose.Schema({
    temperature: Number,
    humidity: Number,
    moisture: Number,
    precipitation: Number,
    motorStatus: String,
    savedWater: Number,
    time: { type: Date, default: Date.now }
});

const Data = mongoose.model("Data", DataSchema);

// POST data from ESP32
app.post("/data", async (req, res) => {
    console.log("Data received from ESP32:", req.body);
    const data = new Data(req.body);
    await data.save();
    res.send("Saved");
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

app.listen(3000, () => console.log("Server running"));
