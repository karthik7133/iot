#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <DHT.h>
#include <ArduinoJson.h>

#define DHTPIN 4
#define DHTTYPE DHT22
#define LED_PIN 2   // LED = Motor

DHT dht(DHTPIN, DHTTYPE);

const char* ssid = "Wokwi-GUEST";
const char* password = "";

// server endpoints
const char* dataEndpoint = "https://iot-0ts3.onrender.com/data";
const char* settingsEndpoint = "https://iot-0ts3.onrender.com/settings";

// Dynamic Config Variables (Defaults)
float lat = 16.3;
float lng = 80.4;
int minMoisture = 40;
int maxMoisture = 70;
float batteryLevel = 100.0; // Simulated battery

void setup() {
  Serial.begin(115200);
  dht.begin();
  pinMode(LED_PIN, OUTPUT);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nConnected to WiFi");
  
  // Initial settings fetch
  fetchSettings();
}

void fetchSettings() {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    http.begin(client, settingsEndpoint);
    int httpCode = http.GET();

    if (httpCode == 200) {
      String payload = http.getString();
      StaticJsonDocument<512> doc;
      DeserializationError error = deserializeJson(doc, payload);

      if (!error) {
        lat = doc["latitude"] | lat;
        lng = doc["longitude"] | lng;
        minMoisture = doc["minMoisture"] | minMoisture;
        maxMoisture = doc["maxMoisture"] | maxMoisture;
        Serial.println("Settings Updated: " + String(lat) + ", " + String(lng) + ", Min: " + String(minMoisture));
      }
    }
    http.end();
  }
}

float getPrecipitation() {
  WiFiClientSecure client;
  client.setInsecure();
  
  // Construct dynamic weather URL
  String weatherURL = "https://api.open-meteo.com/v1/forecast?latitude=" + String(lat) + "&longitude=" + String(lng) + "&hourly=precipitation_probability";
  
  HTTPClient http;
  http.begin(client, weatherURL);
  int httpCode = http.GET();

  float precipitation = 0;

  if (httpCode == 200) {
    String payload = http.getString();
    DynamicJsonDocument doc(2048);
    DeserializationError error = deserializeJson(doc, payload);

    if (!error) {
      precipitation = doc["hourly"]["precipitation_probability"][0];
    }
  }
  
  http.end();
  return precipitation;
}

void loop() {
  // Periodically fetch settings every few minutes (optional, here we do it every loop for simplicity in demo)
  // or use a counter to fetch every 10 loops.
  static int counter = 0;
  if (counter % 10 == 0) {
    fetchSettings();
  }
  counter++;

  float humidity = dht.readHumidity();
  float temp = dht.readTemperature();

  if (isnan(humidity) || isnan(temp)) {
    Serial.println("DHT error");
    delay(2000);
    return;
  }

  // simulate soil moisture %
  int moisture = random(20, 90);

  // get precipitation %
  float precipitation = getPrecipitation();

  // irrigation logic (Dynamic)
  bool motorON = false;
  if (moisture < minMoisture && precipitation < 80) motorON = true;
  if (moisture > maxMoisture || precipitation > 80) motorON = false;

  digitalWrite(LED_PIN, motorON ? HIGH : LOW);
  String motorStatus = motorON ? "ON" : "OFF";

  // battery simulation (drop from 100 to 20 slowly)
  batteryLevel -= 0.5;
  if (batteryLevel < 20) batteryLevel = 100;

  // water saving logic
  float savedWater = 0;
  if (!motorON && precipitation > 80) savedWater = 1;

  Serial.println("--- Sensor Update ---");
  Serial.println("Temp: " + String(temp, 1) + "C, Humidity: " + String(humidity, 1) + "%");
  Serial.println("Moisture: " + String(moisture) + "%, Precp: " + String(precipitation) + "%");
  Serial.println("Motor: " + motorStatus + ", Battery: " + String(batteryLevel) + "%");

  // send to server
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    http.begin(client, dataEndpoint);
    http.addHeader("Content-Type", "application/json");
    
    // Bypass headers for tunnel services if used
    http.addHeader("bypass-tunnel-reminder", "true");
    http.addHeader("X-Tunnel-Skip-Bypass", "true");

    String json = "{";
    json += "\"temperature\":" + String(temp) + ",";
    json += "\"humidity\":" + String(humidity) + ",";
    json += "\"moisture\":" + String(moisture) + ",";
    json += "\"precipitation\":" + String(precipitation) + ",";
    json += "\"motorStatus\":\"" + motorStatus + "\",";
    json += "\"batteryLevel\":" + String(batteryLevel) + ",";
    json += "\"savedWater\":" + String(savedWater);
    json += "}";

    Serial.print("Uploading to DB... ");
    int httpResponseCode = http.POST(json);
    
    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.println("Success! Status: " + String(httpResponseCode));
      Serial.println("Server Response: " + response);
    } else {
      Serial.print("FAILED. Error code: ");
      Serial.println(httpResponseCode);
      Serial.println(http.errorToString(httpResponseCode).c_str());
    }
    
    http.end();
  }

  delay(15000); // 15 sec
}
