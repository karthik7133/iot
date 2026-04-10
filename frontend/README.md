# 🌱 Smart Irrigation — Flutter App (v2)

Flutter mobile frontend for the Smart Irrigation Sequential Zone system.  
Polls the Node.js backend every **3 seconds** via REST to render live water flow progress for Zone 1 and Zone 2.

> **Architecture changed in v2**: The app no longer displays temperature, humidity, battery, or disease risk. It now shows zone-by-zone liquid fill progress driven by MQTT data from ESP32 nodes.

---

## 📁 Lib Structure

```
lib/
├── main.dart                          # App entry, Provider setup, route decision
├── models/
│   └── sensor_data.dart               # ZoneData — zone1/2 progress, precipitation, gatesOpen
├── providers/
│   └── irrigation_provider.dart       # ChangeNotifier, 3-second silent polling
├── screens/
│   ├── onboarding_screen.dart         # 3-slide first-launch intro
│   ├── setup_screen.dart              # One-time GPS + crop configuration
│   ├── dashboard_screen.dart          # Liquid zone cards + precipitation banner
│   └── analytics_screen.dart          # Historical zone + precip charts
├── services/
│   └── data_service.dart              # HTTP client — /live-zones, /settings
└── widgets/
    └── glass_card.dart                # Reusable glassmorphism card
```

---

## 🗂️ Data Model — `ZoneData`

File: `lib/models/sensor_data.dart`

```dart
class ZoneData {
  final int zone1Progress;     // 0 – 100 %
  final int zone2Progress;     // 0 – 100 %
  final double precipitation;  // 0 – 100 % probability (from Open-Meteo via backend)
  final bool gatesOpen;        // true = irrigation running, false = rain closed gates
  final int rainThreshold;     // default 80 — set by backend
  final DateTime? zone1UpdatedAt;
  final DateTime? zone2UpdatedAt;
  final DateTime? precipUpdatedAt;
}
```

**Computed getters:**
```dart
bool get zone1Complete => zone1Progress >= 100;
bool get zone2Complete => zone2Progress >= 100;
bool get allComplete   => zone1Complete && zone2Complete;
bool get rainLikely    => precipitation > rainThreshold;
```

**Constructed from JSON** (`GET /live-zones` response):
```json
{
  "zone1": { "progress": 45, "updatedAt": "..." },
  "zone2": { "progress": 80, "updatedAt": "..." },
  "precipitation": 12,
  "precipUpdatedAt": "...",
  "gatesOpen": true,
  "rainThreshold": 80
}
```

---

## 🔄 State — `IrrigationProvider`

File: `lib/providers/irrigation_provider.dart`

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `zoneData` | `ZoneData` | Live zone + weather state |
| `settings` | `Map<String, dynamic>?` | Crop / location config |
| `isLoading` | `bool` | True only on very first load |
| `hasError` | `bool` | True if last request failed |

### Lifecycle

```
IrrigationProvider()
  └─► _init()
        ├─► refreshData()          // Full load (zones + settings) — sets isLoading
        └─► Timer.periodic(3s)     // _silentRefresh() — fetch /live-zones only, no flicker
```

### Methods

| Method | What it does |
|--------|--------------|
| `refreshData()` | Parallel fetch of `/live-zones` + `/settings`. Used on pull-to-refresh. |
| `_silentRefresh()` | Fetch `/live-zones` only. Does **not** set `isLoading`. No UI flicker. |
| `updateCrop(String)` | `POST /settings` with new crop, then `refreshData()` |

---

## 🌐 Service — `DataService`

File: `lib/services/data_service.dart`

**Base URL:** `https://iot-0ts3.onrender.com`  
**Timeout:** 45 seconds (Render.com free-tier cold starts)

| Method | Endpoint | HTTP | Returns |
|--------|----------|------|---------|
| `pingServer()` | `/ping` | GET | `bool` |
| `fetchLiveZones()` | `/live-zones` | GET | `ZoneData?` |
| `fetchSettings()` | `/settings` | GET | `Map<String, dynamic>?` |
| `updateSettings(...)` | `/settings` | POST | `bool` |

All methods catch exceptions silently and return `null`/`false` — the provider handles degraded state gracefully.

---

## 📱 Screen Reference

### 1. `OnboardingScreen`

Shown only on first launch (no `project_name` in SharedPreferences).

| Feature | Detail |
|---------|--------|
| Slides | 3 animated pages with icon + title + body |
| Animations | Pulsing icon scale (`0.92 → 1.08`, repeat), gradient glow behind icon |
| Navigation dots | Pill dots — active slides expands horizontally |
| CTA Button | "CONTINUE" → "GET STARTED" on final slide |
| Exit | Tapping "GET STARTED" → pushes `SetupScreen` |

---

### 2. `SetupScreen`

One-time field configuration. Cannot be re-triggered without clearing app data.

**User Input Flow:**
1. Enter **Project Name** (text field, validates non-empty)
2. Tap **"Fetch My Location"** → requests `geolocator` permission → stores `lat`, `lng`, builds location label string
3. Select **Crop Type** (horizontal scroll: 🌾 Rice · 🍅 Tomato · 🌿 Cotton)
4. Tap **"Initialize System"**:
   - Calls `DataService.pingServer()` → wakes up Render backend
   - Calls `DataService.updateSettings(lat, lng, cropType, projectName)`
   - Saves to `SharedPreferences`: `project_name`, `crop`, `lat`, `lng`, `location`
   - Navigates to `DashboardScreen`

**API calls made:**
```
GET /ping           → wake-up
POST /settings      → save config
```

---

### 3. `DashboardScreen` ⭐

**Live polling:** `/live-zones` every 3 seconds (silent, via provider timer).  
**Pull-to-refresh:** Full reload of zones + settings.

#### Layout (top → bottom):

1. **Header Row** — Project name, date, notification bell, settings icon
2. **Location Row** — 📍 location label + formatted date
3. **Precipitation Banner** (`_PrecipBanner`)
   - Calls `zoneData.precipitation` and `zoneData.gatesOpen`
   - ☀️ or ☔ icon depending on `zoneData.rainLikely`
   - Shows precipitation % value and a smart status sentence
4. **Section Label** — "Sequential Zone Irrigation"
5. **Zone Cards Row** (`_ZoneCard` × 2) — AspectRatio 1.05, side by side
6. **Overall Progress** (`_OverallProgress`) — ring + avg % + sub-label
7. **Gate Status Row** — Gate status + Rain Risk, two compact cards
8. **Crop Info Card** — Current crop + moisture range, tappable (→ settings sheet)

#### `_ZoneCard` — Liquid Animator

```
CustomPainter (_LiquidPainter)
  ├─ Draws 2 overlapping sine waves in neon cyan or success green
  ├─ Wave phase advances via AnimationController (3s repeat)
  └─ Fill height = containerHeight × (1 - progress/100)
```

| Progress | Border | Liquid | Status Badge | Label |
|----------|--------|--------|--------------|-------|
| 0–99% | Cyan 50% opacity | Cyan (#00E5FF) | `LIVE` (cyan) | "Filling..." |
| 100% | Green glow | Green (#00E676) | `DONE` (green) | "✔ Irrigation Complete" |
| Gates Closed | Orange | Cyan | `PAUSED` (orange) | "⏸ Gates Closed" |

#### `_CropSettingsSheet` (Bottom Sheet)

Opened via the ⚙️ / tune icon in header.

| Element | Behavior |
|---------|----------|
| Info rows | Shows current crop + moisture range (read from `provider.settings`) |
| Crop tiles | `AnimatedContainer` — Rice 🌾 / Tomato 🍅 / Cotton 🌿 |
| SAVE button | Gradient button → calls `provider.updateCrop()` → `POST /settings` |

---

### 4. `AnalyticsScreen` ⭐

Accessed via "Insights" FAB on Dashboard.  
Makes its own `GET /history` request directly (not through provider).

#### Data flow:
```
initState()
  └─► _loadHistory()
        └─► GET /history (up to 50 snapshots)
              └─► maps JSON → List<_ZoneSnapshot>
```

#### `_ZoneSnapshot` (internal model):
```dart
class _ZoneSnapshot {
  int zone1Progress;
  int zone2Progress;
  double precipitation;
  DateTime time;
}
```

#### Layout:

| Section | Data source | Chart type |
|---------|-------------|------------|
| Live Snapshot row | `IrrigationProvider.zoneData` | 3 stat cards (zone1, zone2, rain) |
| Zone Progress History | `GET /history` snapshots | Dual line chart (cyan + green) |
| Chart Legend | Static | Zone 1 🔵 · Zone 2 🟢 |
| Precipitation History | `GET /history` snapshots | Single line chart (orange) |
| Session Stats | Computed from snapshots | 3 stat cards (count, avg rain, rain events) |

**Error/Empty states:** Shows `GlassCard` with descriptive message for both cases.  
**Pull-to-refresh:** Re-runs `_loadHistory()`.

---

## 🎨 Design Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| Background dark | `#0F2027` | Scaffold, gradient start |
| Background mid | `#203A43` | Gradient end |
| Neon Cyan | `#00E5FF` | Zone fill, progress bars, accents |
| Success Green | `#00E676` | Zone complete, gate open, low rain |
| Amber Orange | `#FF9100` | Gates closed, rain warning |
| Alert Red | `#D50000` | Error states |
| Font | Outfit (Google Fonts) | All text throughout |

**`GlassCard` widget defaults:**
- `blur`: 12
- `opacity`: 0.08 (background fill)
- `borderRadius`: 24
- `borderOpacity`: 0.3

---

## 📦 All Dependencies

```yaml
dependencies:
  google_fonts: ^8.0.1         # Outfit typeface
  provider: ^6.1.5+1           # State management
  fl_chart: ^1.1.1             # Line charts (Analytics)
  percent_indicator: ^4.2.5    # Circular ring (Analytics snapshot)
  http: ^1.6.0                 # REST calls to backend
  shared_preferences: ^2.5.4   # Local storage (setup data)
  intl: ^0.20.2                # Date formatting
  geolocator: ^13.0.2          # GPS on Setup Screen

dev_dependencies:
  flutter_launcher_icons: ^0.14.3  # App icon generation
```

---

## 🚀 Run the App

```bash
cd frontend/
flutter pub get
flutter run
```

For a release APK:
```bash
flutter build apk --release
```

---

## 📄 Removed from v1

| Removed | Reason |
|---------|--------|
| `batteryLevel` field | ESP32 no longer reports battery via HTTP |
| `diseaseRisk` field | Disease prediction removed — no temp/humidity data |
| `motorStatus` field | Replaced by `gatesOpen` (backend-controlled via MQTT) |
| `temperature`, `humidity` fields | ESP32 nodes no longer POST sensor readings |
| `moisture` field | No longer tracked (gate logic is time/flow based) |
| `IrrigationStats` class | `waterSavedPercent` endpoint removed from backend |
| `fetchLatestData()` | Replaced by `fetchLiveZones()` |
| `fetchStats()` | `/stats` endpoint removed |
| `fetchHistory()` | Analytics screen now fetches directly |
| `Timer.periodic(10s)` | Replaced by `Timer.periodic(3s)` |
| Old Dashboard hero card | Replaced by 2-column liquid zone cards |
| "Disease Prediction" card | Removed — no AI disease risk in v2 |
| "Battery Health" tile | Removed — no battery reporting in v2 |
| "Temperature" tile | Removed — no temp reporting in v2 |
