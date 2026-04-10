//board 1 code ................
import network
import time
import ujson
from machine import Pin, ADC, PWM
from umqtt.simple import MQTTClient

# --- Wokwi Hardware Setup ---
gate_servo = PWM(Pin(15), freq=50)
s1 = ADC(Pin(32))
s2 = ADC(Pin(33))
s3 = ADC(Pin(34))
s4 = ADC(Pin(35))

for s in [s1, s2, s3, s4]:
    s.atten(ADC.ATTN_11DB)

# --- Network & MQTT Settings ---
WIFI_SSID = "Wokwi-GUEST"
WIFI_PASS = ""
MQTT_BROKER = "broker.hivemq.com" 
CLIENT_ID = "esp32_zone1"

TOPIC_PROGRESS = b"smartfarm/zone1/progress"  # To Server/App
TOPIC_CONTROL = b"smartfarm/control"          # From Server (Weather)
TOPIC_SEQUENCE = b"smartfarm/sequence"        # To Board 2

# Global State
system_enabled = True # Controlled by the server's weather check
zone_completed = False

def connect_wifi():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    wlan.connect(WIFI_SSID, WIFI_PASS)
    print("Connecting to WiFi...", end="")
    while not wlan.isconnected():
        time.sleep(0.5)
    print("\nConnected to WiFi!")

def open_gate():
    print("Opening Gate 1...")
    gate_servo.duty(115) 

def close_gate():
    print("Closing Gate 1...")
    gate_servo.duty(40)  

def map_sensor_to_percent(adc_val):
    return int((adc_val / 4095.0) * 100)

# --- Listen for Server Weather Overrides ---
def mqtt_callback(topic, msg):
    global system_enabled
    if topic == TOPIC_CONTROL:
        try:
            # Server sends JSON: {"command": "CLOSE", "timestamp": ...}
            data = ujson.loads(msg)
            command = data.get("command", "")
            if command == "CLOSE":
                print("☁️ SERVER OVERRIDE: Rain Expected. Pausing Gate 1.")
                system_enabled = False
                close_gate()
            elif command == "OPEN":
                print("☀️ SERVER OVERRIDE: Clear Weather. Resuming.")
                system_enabled = True
                if not zone_completed:
                    open_gate()
        except:
            pass

def main():
    global zone_completed
    connect_wifi()
    
    client = MQTTClient(CLIENT_ID, MQTT_BROKER)
    client.set_callback(mqtt_callback)
    client.connect()
    
    # Subscribe to server commands
    client.subscribe(TOPIC_CONTROL)
    print(f"Connected to MQTT. Subscribed to {TOPIC_CONTROL}")
    
    # Start irrigation if weather allows
    if system_enabled:
        open_gate()

    while not zone_completed:
        # Check for incoming server messages
        client.check_msg()
        
        val1 = map_sensor_to_percent(s1.read())
        val2 = map_sensor_to_percent(s2.read())
        val3 = map_sensor_to_percent(s3.read())
        val4 = map_sensor_to_percent(s4.read())
        
        overall_progress = (val1 + val2 + val3 + val4) // 4
        
        # Exact payload required by your new README
        payload = ujson.dumps({
            "zone": 1,
            "progress": overall_progress
        })
        
        client.publish(TOPIC_PROGRESS, payload)
        print(f"Zone 1 Progress: {overall_progress}% -> Server")
        
        if overall_progress >= 95:
            print("✅ Zone 1 Fully Watered!")
            close_gate()
            # Tell Board 2 to start!
            client.publish(TOPIC_SEQUENCE, b"START_ZONE_2")
            zone_completed = True
            
        time.sleep(2)

if __name__ == "__main__":
    main()


// board 2 code...............
import network
import time
import ujson
from machine import Pin, ADC, PWM
from umqtt.simple import MQTTClient

# --- Wokwi Hardware Setup ---
gate_servo = PWM(Pin(15), freq=50)
s1 = ADC(Pin(32))
s2 = ADC(Pin(33))
s3 = ADC(Pin(34))
s4 = ADC(Pin(35))

for s in [s1, s2, s3, s4]:
    s.atten(ADC.ATTN_11DB)

# --- Network & MQTT Settings ---
WIFI_SSID = "Wokwi-GUEST"
WIFI_PASS = ""
MQTT_BROKER = "broker.hivemq.com" 
CLIENT_ID = "esp32_zone2"

TOPIC_PROGRESS = b"smartfarm/zone2/progress"  # To Server/App
TOPIC_CONTROL = b"smartfarm/control"          # From Server (Weather)
TOPIC_SEQUENCE = b"smartfarm/sequence"        # From Board 1

# Global State
system_enabled = True # Controlled by server weather
start_irrigation = False
zone_completed = False

def connect_wifi():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    wlan.connect(WIFI_SSID, WIFI_PASS)
    print("Connecting to WiFi...", end="")
    while not wlan.isconnected():
        time.sleep(0.5)
    print("\nConnected to WiFi!")

def open_gate():
    print("Opening Gate 2...")
    gate_servo.duty(115) 

def close_gate():
    print("Closing Gate 2...")
    gate_servo.duty(40)  

def map_sensor_to_percent(adc_val):
    return int((adc_val / 4095.0) * 100)

# --- Listen for BOTH Board 1 and the Server ---
def mqtt_callback(topic, msg):
    global system_enabled, start_irrigation
    
    # 1. Listen for Board 1's turn-over signal
    if topic == TOPIC_SEQUENCE:
        if msg == b"START_ZONE_2":
            print("👉 Received sequence trigger from Zone 1!")
            start_irrigation = True
            if system_enabled and not zone_completed:
                open_gate()
                
    # 2. Listen for Server Weather Overrides
    elif topic == TOPIC_CONTROL:
        try:
            data = ujson.loads(msg)
            command = data.get("command", "")
            if command == "CLOSE":
                print("☁️ SERVER OVERRIDE: Rain Expected. Pausing Gate 2.")
                system_enabled = False
                close_gate()
            elif command == "OPEN":
                print("☀️ SERVER OVERRIDE: Clear Weather. Ready.")
                system_enabled = True
                # Only open if it is actually our turn
                if start_irrigation and not zone_completed:
                    open_gate()
        except:
            pass

def main():
    global zone_completed
    connect_wifi()
    close_gate()
    
    client = MQTTClient(CLIENT_ID, MQTT_BROKER)
    client.set_callback(mqtt_callback)
    client.connect()
    
    # Subscribe to both topics!
    client.subscribe(TOPIC_CONTROL)
    client.subscribe(TOPIC_SEQUENCE)
    print("Connected to MQTT. Waiting for turn...")
    
    # Idle loop: Wait for Board 1
    while not start_irrigation:
        client.check_msg()
        time.sleep(0.5)

    # Action loop
    while not zone_completed:
        client.check_msg()
        
        val1 = map_sensor_to_percent(s1.read())
        val2 = map_sensor_to_percent(s2.read())
        val3 = map_sensor_to_percent(s3.read())
        val4 = map_sensor_to_percent(s4.read())
        
        overall_progress = (val1 + val2 + val3 + val4) // 4
        
        payload = ujson.dumps({
            "zone": 2,
            "progress": overall_progress
        })
        
        client.publish(TOPIC_PROGRESS, payload)
        print(f"Zone 2 Progress: {overall_progress}% -> Server")
        
        if overall_progress >= 95:
            print("✅ Zone 2 Fully Watered!")
            close_gate()
            zone_completed = True
            
        time.sleep(2)

if __name__ == "__main__":
    main()
