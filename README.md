# 🌱 Smart Irrigation System — Sequential Zone Irrigation

A full-stack IoT smart irrigation system using **ESP32 nodes (MQTT)**, a **Node.js + Express backend**, **MongoDB Atlas** for persistence, and a **Flutter mobile app** for monitoring and control.

## 🆕 Architecture (v2 — Sequential Zone Irrigation)

The system has been refactored from a single-ESP32 "smart" node to a **distributed MQTT-based architecture**:

| Component | Old Role | New Role |
|-----------|----------|----------|
| ESP32 nodes | Decision-making + HTTP POST | Dumb nodes — publish flow progress via MQTT |
| Backend (`server.js`) | Passive data receiver | Active "Smart Brain" — weather polling, gate control |
| Flutter App | Polls `/latest` every 10s | Polls `/live-zones` every **3 seconds** |

```
ESP32 Zone 1 ──► MQTT Publish: smartfarm/zone1/progress
ESP32 Zone 2 ──► MQTT Publish: smartfarm/zone2/progress
                                     │
                         broker.hivemq.com (public broker)
                                     │
                              Node.js Backend
                         ┌───────────┴────────────┐
                         │   Smart Brain (5 min)  │
                         │   Open-Meteo API call  │
                         │   If rain > 80%:       │
                         │   MQTT CLOSE all gates │
                         └───────────┬────────────┘
                                     │ REST API
                                     ▼
                            Flutter App (polls /live-zones every 3s)
```

---

## 📁 Project Structure

```
iot/
├── server.js              # Node.js + Express + MQTT backend
├── package.json           # Backend dependencies (express, mongoose, cors, mqtt)
├── iot.ino                # ESP32 Arduino sketch (MQTT publisher)
└── frontend/              # Flutter mobile app
    ├── lib/
    │   ├── main.dart
    │   ├── models/
    │   │   └── sensor_data.dart        # ZoneData model
    │   ├── providers/
    │   │   └── irrigation_provider.dart
    │   ├── screens/
    │   │   ├── onboarding_screen.dart
    │   │   ├── setup_screen.dart
    │   │   ├── dashboard_screen.dart   # Liquid animation zone cards
    │   │   └── analytics_screen.dart   # Zone progress + precip charts
    │   ├── services/
    │   │   └── data_service.dart
    │   └── widgets/
    │       └── glass_card.dart
    ├── assets/
    │   └── icons/
    │       └── app_icon.png
    └── pubspec.yaml
```

---

## 🖥️ Backend — `server.js`

### NPM Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `express` | ^5.2.1 | HTTP REST API server |
| `mongoose` | ^9.2.1 | MongoDB Atlas ODM |
| `cors` | ^2.8.6 | Cross-origin requests |
| `mqtt` | latest | MQTT client (HiveMQ broker) |
| `https` | built-in | Open-Meteo weather API calls |

### MongoDB Collections

#### `zone_logs` — Zone Snapshot (saved every 5 min by the Smart Brain)
```json
{
  "zone1Progress": 45,
  "zone2Progress": 80,
  "precipitation": 12,
  "gatesOpen": true,
  "time": "2026-04-10T10:30:00.000Z"
}
```

#### `settings` — User/Field Configuration (written by the Flutter app)
```json
{
  "projectName": "My Smart Farm",
  "latitude": 16.3,
  "longitude": 80.4,
  "cropType": "Rice",
  "minMoisture": 60,
  "maxMoisture": 80,
  "lastUpdated": "2026-04-10T09:00:00.000Z"
}
```

---

### 📡 MQTT Integration

**Broker:** `mqtt://broker.hivemq.com` (public, no auth)  
**Client ID:** `smart-irrigation-server-<random>` (unique per restart)  
**Reconnect Policy:** Auto-reconnects every 5 seconds on drop  
**QoS:** 1 (at least once delivery)

#### Topics Subscribed (Backend listens)

| Topic | Direction | Payload |
|-------|-----------|---------|
| `smartfarm/zone1/progress` | ESP32 → Backend | `{ "zone": 1, "progress": 45 }` |
| `smartfarm/zone2/progress` | ESP32 → Backend | `{ "zone": 2, "progress": 80 }` |

#### Topics Published (Backend sends)

| Topic | Trigger | Payload |
|-------|---------|---------|
| `smartfarm/control` | Every 5 min weather check | `{ "command": "OPEN" \| "CLOSE", "timestamp": 000 }` |

**Gate Logic:**
- Precipitation probability **> 80%** → Publishes `CLOSE` (stops all zones, saves water)
- Precipitation probability **≤ 80%** → Publishes `OPEN` (allows irrigation to proceed)

---

### 🌦️ Weather "Smart Brain" — `setInterval` (every 5 minutes)

1. Reads `latitude` and `longitude` from the MongoDB `settings` collection
2. Calls **Open-Meteo API** to get current hour's precipitation probability
3. Applies gate control logic (see above)
4. **Saves a `ZoneLog` snapshot** to MongoDB with current zone progress + precipitation

**External API called:**
```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={lat}
  &longitude={lon}
  &hourly=precipitation_probability
  &forecast_days=1
  &timezone=auto
```
> Extracts `hourly.precipitation_probability[currentHour]` to get the live probability.

---

## 🔌 REST API Reference

**Base URL:** `https://iot-0ts3.onrender.com`  
*(Hosted on Render.com free tier — may have 20–40s cold start on first request)*

---

### `GET /`
Server health check.  
**Response:** `"Smart Irrigation Server — ALIVE ✅"` (200 OK)

---

### `GET /ping`
Wake-up call (used by Flutter app on setup).  
**Response:** `"pong"` (200 OK)

---

### `GET /live-zones` ⭐ Primary Flutter Endpoint

Returns the **live in-memory state** of both irrigation zones plus latest weather data. This is what the Flutter app polls every 3 seconds.

**Response:**
```json
{
  "zone1": {
    "progress": 45,
    "updatedAt": "2026-04-10T10:31:00.000Z"
  },
  "zone2": {
    "progress": 80,
    "updatedAt": "2026-04-10T10:31:05.000Z"
  },
  "precipitation": 12,
  "precipUpdatedAt": "2026-04-10T10:30:00.000Z",
  "gatesOpen": true,
  "rainThreshold": 80
}
```

> `progress` is updated in real-time as MQTT messages arrive from ESP32 nodes.  
> `precipitation` is updated every 5 minutes by the Smart Brain.

---

### `GET /history`
Returns the last 50 MongoDB zone log snapshots (oldest → newest).  
Used by **Analytics Screen** to render historical charts.

**Response:**
```json
[
  {
    "zone1Progress": 20,
    "zone2Progress": 35,
    "precipitation": 5,
    "gatesOpen": true,
    "time": "2026-04-10T09:00:00.000Z"
  },
  ...
]
```

---

### `GET /settings`
Fetch current field configuration. Used internally, and by the Flutter Setup Screen on re-open.

**Response:**
```json
{
  "projectName": "My Smart Farm",
  "latitude": 16.3,
  "longitude": 80.4,
  "cropType": "Rice",
  "minMoisture": 60,
  "maxMoisture": 80,
  "lastUpdated": "2026-04-10T09:00:00.000Z"
}
```

---

### `POST /settings` *(Called by Flutter App)*
Save or update field configuration. Auto-derives moisture thresholds from crop type.

**Request Body:**
```json
{
  "projectName": "My Smart Farm",
  "latitude": 17.38,
  "longitude": 78.47,
  "cropType": "Rice"
}
```

**Crop → Moisture Threshold Mapping (auto-applied):**

| Crop | `minMoisture` | `maxMoisture` |
|------|--------------|--------------|
| Rice | 60 | 80 |
| Tomato | 40 | 60 |
| Cotton | 30 | 50 |
| Default | 40 | 70 |

**Response:**
```json
{ "message": "Settings Updated", "settings": { ... } }
```

---

### ~~`POST /data`~~ — **REMOVED in v2**
> This endpoint previously accepted sensor data from the ESP32 via HTTP POST. It has been **removed**. ESP32 nodes now publish progress via MQTT.

### ~~`GET /latest`~~ — **REMOVED in v2**
> Replaced by `GET /live-zones`.

### ~~`GET /stats`~~ — **REMOVED in v2**
> Water-saved percentage was based on old `motorStatus` field, which no longer exists.

---

## 📱 Flutter App

### 📦 Dependencies (`pubspec.yaml`)

| Package | Version | Purpose |
|---------|---------|---------|
| `google_fonts` | ^8.0.1 | Outfit font throughout the app |
| `provider` | ^6.1.5+1 | State management (`ChangeNotifier`) |
| `fl_chart` | ^1.1.1 | Line charts in Analytics Screen |
| `percent_indicator` | ^4.2.5 | Circular ring in Analytics snapshot |
| `http` | ^1.6.0 | REST API calls to backend |
| `shared_preferences` | ^2.5.4 | Local persistence (project name, location) |
| `intl` | ^0.20.2 | Date formatting (`EEE, MMM d`) |
| `geolocator` | ^13.0.2 | GPS coordinate fetching on setup |
| `flutter_launcher_icons` | ^0.14.3 | App icon generation |

---

### 🗂️ Data Model — `ZoneData` (`sensor_data.dart`)

Replaces the old `SensorData` model. No more `temperature`, `humidity`, `batteryLevel`, `diseaseRisk`, `motorStatus`.

```dart
class ZoneData {
  final int zone1Progress;     // 0–100 %
  final int zone2Progress;     // 0–100 %
  final double precipitation;  // 0–100 % probability
  final bool gatesOpen;
  final int rainThreshold;     // default 80
  final DateTime? zone1UpdatedAt;
  final DateTime? zone2UpdatedAt;
  final DateTime? precipUpdatedAt;

  // Computed helpers
  bool get zone1Complete => zone1Progress >= 100;
  bool get zone2Complete => zone2Progress >= 100;
  bool get allComplete   => zone1Complete && zone2Complete;
  bool get rainLikely    => precipitation > rainThreshold;
}
```

---

### 🔄 State Management — `IrrigationProvider`

`ChangeNotifier` powered provider mounted at app root via `MultiProvider`.

| State | Type | Description |
|-------|------|-------------|
| `zoneData` | `ZoneData` | Live zone progress + precipitation |
| `settings` | `Map<String, dynamic>?` | Crop / location config from backend |
| `isLoading` | `bool` | True only during initial load |
| `hasError` | `bool` | Set if the last network call failed |

**Polling Strategy:**
- `_init()` fires `refreshData()` once (full load: zones + settings)
- `Timer.periodic(Duration(seconds: 3))` calls `_silentRefresh()` — fetches only `/live-zones`, does **not** flip `isLoading`, preventing UI flicker
- Pull-to-refresh triggers `refreshData()` (full: zones + settings)

**API Calls Made:**

| Method | Endpoint | When |
|--------|----------|------|
| `GET /live-zones` | Every **3 seconds** (silent) + on pull-to-refresh |
| `GET /settings` | On first init + on pull-to-refresh |
| `POST /settings` | When user saves crop type in Settings sheet |
| `GET /ping` | On Setup Screen "Initialize System" tap |

---

### 🗺️ Data Service — `DataService` (`data_service.dart`)

| Method | HTTP Call | Returns |
|--------|-----------|---------|
| `pingServer()` | `GET /ping` | `bool` |
| `fetchLiveZones()` | `GET /live-zones` | `ZoneData?` |
| `fetchSettings()` | `GET /settings` | `Map<String, dynamic>?` |
| `updateSettings(...)` | `POST /settings` | `bool` |

**Base URL:** `https://iot-0ts3.onrender.com`  
**Request Timeout:** 45 seconds (accounts for Render free-tier cold start)

---

## 📱 Screens

### 1. Onboarding Screen (`onboarding_screen.dart`)
Shown once on first launch. 3-slide animated intro carousel.

| Slide | Title | Description |
|-------|-------|-------------|
| 1 | Smart Irrigation | AI-powered water management intro |
| 2 | Real-time Analytics | Soil health monitoring |
| 3 | Sequential Zone AI | Adaptive zone-based irrigation |

**Features:** Pulsing icon animation, gradient glow, animated dot indicators, glassmorphism CTA button → navigates to Setup Screen.

---

### 2. Setup Screen (`setup_screen.dart`)
One-time setup before first use.

| Field | Description |
|-------|-------------|
| Project Name | Free text input |
| Location | GPS auto-fetch via `geolocator` |
| Crop Selector | Rice 🌾 / Tomato 🍅 / Cotton 🌿 |
| Initialize System button | Pings backend → `POST /settings` → saves to `SharedPreferences` → navigates to Dashboard |

**SharedPreferences keys written:**
```
project_name   String
crop           String
lat            double
lng            double
location       String  (human-readable label)
```

---

### 3. Dashboard Screen (`dashboard_screen.dart`) ⭐ Redesigned

The primary live-data screen. Polls `/live-zones` every **3 seconds**.

#### Header
- Project name + "Smart Irrigation" subtitle
- Location label + current date
- Notification bell icon
- Settings/tune icon → opens Crop Settings Sheet

#### Precipitation / Weather Banner
Displays a live weather summary card:
- ☀️ Clear weather → `"No rain (X%) — Irrigation active"` (green accent)
- ☔ Rain alert → `"Rain likely (X%) — Gates closed to save water"` (orange accent)
- Shows live precipitation % value prominently

#### Sequential Zone Cards (2-column hero layout)

Two side-by-side animated cards representing **Zone 1** and **Zone 2**:

| State | Visual |
|-------|--------|
| Filling (0–99%) | Neon cyan (`#00E5FF`) liquid rising with animated sine waves. `LIVE` badge. |
| Complete (100%) | Success green (`#00E676`) border glow, text turns green. `DONE` badge. |
| Gates Closed | Orange border, `PAUSED` badge, shows "Gates Closed" text. |

**Liquid Animation Details:**
- Built with a custom `CustomPainter` (`_LiquidPainter`)
- Two overlapping sine-wave layers for realistic liquid effect
- `AnimationController` (3s repeat) drives the wave phase offset
- Fill height = `containerHeight × (1 - progress / 100)`
- Thin `LinearProgressIndicator` bar at bottom of each card

#### Overall Progress Ring
- Circular ring showing average of Zone 1 + Zone 2
- Cyan while filling, turns green at 100%
- Sub-label: `"Zone 1: X% · Zone 2: Y%"` or `"All zones fully irrigated 🎉"`

#### Gate & Rain Status Row
Two compact info cards side by side:
- **Gate Status**: green `OPEN` or orange `CLOSED` with live dot indicator
- **Rain Risk**: `LOW` (green) or `HIGH` (orange) based on precipitation vs threshold

#### Crop Info Card
Tap to open settings sheet. Shows:
- Current selected crop with 🌿 icon
- Moisture target range (e.g. `60% – 80%`)
- Chevron arrow indicating it's tappable

#### Crop Settings Bottom Sheet (`_CropSettingsSheet`)
- Shows current crop + moisture range
- 3 animated crop option tiles: Rice 🌾, Tomato 🍅, Cotton 🌿
- Selected crop gets green highlight border + animated transition (`AnimatedContainer`)
- "SAVE SETTINGS" → calls `POST /settings` → updates provider

#### FAB (Floating Action Button)
→ Navigates to **Analytics Screen**

---

### 4. Analytics Screen (`analytics_screen.dart`) ⭐ Redesigned

Accessed via "Insights" FAB. Fetches from `GET /history` directly (not through provider).

#### Live Snapshot Row (from provider)
3 stat cards showing current live values:
| Card | Value | Color |
|------|-------|-------|
| Zone 1 | Current progress % | Neon Cyan |
| Zone 2 | Current progress % | Success Green |
| Rain | Current precipitation % | Orange |

#### Zone Progress History Chart
- Dual line chart (Zone 1 = cyan, Zone 2 = green)
- X-axis = snapshot index, Y-axis = 0–100%
- Gradient fill below Zone 1 line
- Uses `fl_chart` — `LineChart` with smooth curves

#### Chart Legend
- 🔵 Zone 1 (cyan dot + label)
- 🟢 Zone 2 (green dot + label)

#### Precipitation History Chart
- Single line chart (orange)
- Shows precipitation probability over snapshots
- Y-axis = 0–100%

#### Session Stats Row
3 stat cards calculated from snapshot history:
| Card | Calculation |
|------|-------------|
| Snapshots | Total count of `/history` records |
| Avg Rain | Mean precipitation across all snapshots |
| Rain Events | Count of snapshots where precipitation > 80% |

**Error States:** Shows error card if `/history` fetch fails. Shows empty state if no snapshots yet.
**Pull to Refresh:** Reloads history from backend.

---

## 🎨 Design System

| Token | Value |
|-------|-------|
| Background gradient | `#0F2027` → `#203A43` (top-left to bottom-right) |
| Primary accent | `#00E5FF` — Neon Cyan (water/zones filling) |
| Success | `#00E676` — Bright Green (zone complete, gate open, low rain risk) |
| Warning | `#FF9100` — Amber Orange (gates closed, rain risk) |
| Error / Alert | `#D50000` — Red |
| Font | **Outfit** (Google Fonts) |
| Card Style | Glassmorphism — `BackdropFilter`, white border + fill with opacity |

**GlassCard Widget** (`glass_card.dart`):  
Used on every screen for all cards and panels.
- Default `blur`: 12
- Default `opacity`: 0.08
- Default `borderRadius`: 24
- Default `borderOpacity`: 0.3

---

## 🔧 Hardware — `iot.ino` (ESP32)

The ESP32 is now a **dumb MQTT publisher**. All decision logic has moved to the backend.

| Component | Pin | Purpose |
|-----------|-----|---------| 
| Solenoid/Pump (Zone 1) | GPIO configurable | Controls gate open/close |
| Solenoid/Pump (Zone 2) | GPIO configurable | Controls gate open/close |
| Flow Sensor (Zone 1) | GPIO configurable | Measures water flow → % progress |

**Loop Logic:**
1. Measures water flow progress (0–100%) for Zone 1 and Zone 2
2. Publishes progress to MQTT broker every loop:
   - `smartfarm/zone1/progress` → `{ "zone": 1, "progress": <value> }`
   - `smartfarm/zone2/progress` → `{ "zone": 2, "progress": <value> }`
3. Subscribes to `smartfarm/control` → on `CLOSE` command, shuts gate solenoids; on `OPEN`, reopens them

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `>=3.10.3`
- Node.js `>=18`
- Arduino IDE with ESP32 board support

### Run the Backend
```bash
cd iot/
npm install
node server.js
```
> On first start, the server connects to MQTT broker, fetches weather, and begins the 5-minute Smart Brain loop.

### Run the Flutter App
```bash
cd iot/frontend/
flutter pub get
flutter run
```

### Flash the ESP32
Open `iot.ino` in Arduino IDE. Configure WiFi credentials and the MQTT broker address (`broker.hivemq.com`). Flash to your ESP32.

---

## 📄 App Flow Summary

```
First Launch:
  Onboarding (3 slides)
    → Setup Screen (project name + GPS + crop)
      → POST /settings (saves config to MongoDB)
        → Dashboard

Returning User:
  Dashboard
    ← polls GET /live-zones every 3s (silent, no flicker)
    ← polls GET /settings on full refresh

Dashboard → ⚙️ Icon → Crop Settings Sheet → POST /settings
Dashboard → "Insights" FAB → Analytics Screen → GET /history

Backend (every 5 min):
  GET Open-Meteo weather API
    → rain > 80%? → MQTT CLOSE → save ZoneLog to MongoDB
    → rain ≤ 80%? → MQTT OPEN  → save ZoneLog to MongoDB
```

---

## 🔄 What Changed from v1 → v2

| Area | v1 (Old) | v2 (New) |
|------|----------|----------|
| ESP32 role | Decision maker + HTTP POST | Dumb MQTT publisher |
| Data transport | HTTP POST `/data` | MQTT `smartfarm/zone*/progress` |
| Weather polling | Done on ESP32 | Done on backend (Smart Brain) |
| Gate control | ESP32 decides locally | Backend publishes MQTT command |
| App poll interval | 10 seconds | **3 seconds** |
| App primary endpoint | `GET /latest` | `GET /live-zones` |
| Data model | `SensorData` (temp/humidity/battery/diseaseRisk) | `ZoneData` (zone1/zone2 progress + precipitation) |
| Dashboard Hero | Motor status + pulsing glow | **2-column liquid fill animation** |
| Analytics | Temp / Humidity / Moisture charts | Zone Progress + Precipitation charts |
| Removed endpoints | — | `POST /data`, `GET /latest`, `GET /stats` |
