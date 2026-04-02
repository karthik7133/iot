import network
import urequests as requests
import dht
from machine import Pin
import ujson as json
import time
import random

# --- Pin Setup ---
DHT_PIN = 4
LED_PIN = 2  # LED = Motor

sensor = dht.DHT22(Pin(DHT_PIN))
motor = Pin(LED_PIN, Pin.OUT)

# --- Network & Endpoints ---
ssid = "EliteNet-Nirvana_101"
password = "9790815877"

data_endpoint = "https://iot-0ts3.onrender.com/data"
settings_endpoint = "https://iot-0ts3.onrender.com/settings"

# --- Dynamic Config Variables (Defaults) ---
lat = 16.3
lng = 80.4
min_moisture = 40
max_moisture = 70
battery_level = 100.0

def connect_wifi():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    if not wlan.isconnected():
        print('Connecting to WiFi...')
        wlan.connect(ssid, password)
        while not wlan.isconnected():
            time.sleep(0.5)
            print(".", end="")
    print('\nConnected to WiFi')
    print('Network config:', wlan.ifconfig())

def fetch_settings():
    global lat, lng, min_moisture, max_moisture
    try:
        response = requests.get(settings_endpoint)
        if response.status_code == 200:
            data = response.json()
            lat = data.get("latitude", lat)
            lng = data.get("longitude", lng)
            min_moisture = data.get("minMoisture", min_moisture)
            max_moisture = data.get("maxMoisture", max_moisture)
            print(f"Settings Updated: {lat}, {lng}, Min: {min_moisture}")
        response.close()
    except Exception as e:
        print("Failed to fetch settings:", e)

def get_weather_data():
    # Ask for precipitation, temp, and humidity all in one URL
    weather_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}&hourly=precipitation_probability&current=temperature_2m,relative_humidity_2m"
    try:
        response = requests.get(weather_url)
        if response.status_code == 200:
            data = response.json()
            
            # Extract all three values
            precip = data["hourly"]["precipitation_probability"][0]
            api_temp = data["current"]["temperature_2m"]
            api_humidity = data["current"]["relative_humidity_2m"]
            
            response.close()
            # Return all three as a tuple
            return precip, api_temp, api_humidity
            
        response.close()
    except Exception as e:
        print("Failed to fetch weather:", e)
        
    # If the API fails, return safe defaults (0% precip, 25C temp, 50% humidity)
    return 0, 25.0, 50.0

def main():
    global battery_level
    connect_wifi()
    fetch_settings()

    counter = 0

    while True:
        # Fetch settings every 10 loops
        if counter % 10 == 0 and counter != 0:
            fetch_settings()
        counter += 1

        # 1. Fetch the API data FIRST
        precipitation, api_temp, api_humidity = get_weather_data()

        # 2. THEN Read DHT Sensor
        try:
            sensor.measure()
            temp = sensor.temperature()
            humidity = sensor.humidity()
            print("Using physical DHT sensor data.")
        except OSError as e:
            print("DHT error. Using API fallback data...")
            # Now this works perfectly because api_temp and api_humidity already exist!
            temp = api_temp
            humidity = api_humidity

        # Simulate soil moisture %
        moisture = random.randint(20, 90)

        # Irrigation logic (Dynamic)
        motor_on = False
        if moisture < min_moisture and precipitation < 80:
            motor_on = True
        if moisture > max_moisture or precipitation > 80:
            motor_on = False

        motor.value(1 if motor_on else 0)
        motor_status = "ON" if motor_on else "OFF"

        # Battery simulation
        battery_level -= 0.5
        if battery_level < 20:
            battery_level = 100

        # Water saving logic
        saved_water = 1 if not motor_on and precipitation > 80 else 0

        print("\n--- Sensor Update ---")
        print(f"Temp: {temp:.1f}C, Humidity: {humidity:.1f}%")
        print(f"Moisture: {moisture}%, Precp: {precipitation}%")
        print(f"Motor: {motor_status}, Battery: {battery_level}%")

        # Send to server
        headers = {
            "Content-Type": "application/json",
            "bypass-tunnel-reminder": "true",
            "X-Tunnel-Skip-Bypass": "true"
        }

        # MicroPython dictionaries convert perfectly to JSON
        payload = {
            "temperature": temp,
            "humidity": humidity,
            "moisture": moisture,
            "precipitation": precipitation,
            "motorStatus": motor_status,
            "batteryLevel": battery_level,
            "savedWater": saved_water
        }

        try:
            print("Uploading to DB... ", end="")
            response = requests.post(data_endpoint, json=payload, headers=headers)
            print(f"Success! Status: {response.status_code}")
            print("Server Response:", response.text)
            response.close()
        except Exception as e:
            print("FAILED. Error:", e)

        time.sleep(15)  # Wait 15 seconds

if __name__ == "__main__":
    main()

if everything is fine we will connect to wifi and start running the server and esp32 device okay?
