#!/usr/bin/env python3
"""
MQTT Face Authentication Bridge
Connects the Flutter app (MQTT) to the face recognition service (REST API)

This bridge enables Flutter app to communicate with face detection service via MQTT.
Supports both Docker and Windows deployments.
"""
import json
import time
import os
import requests
from paho.mqtt import client as mqtt_client

# Configuration - Use environment variables for flexibility
MQTT_BROKER = os.getenv("MQTT_BROKER", "192.168.1.7")  # "192.168.1.7" for network access, "localhost" for local only
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
CLIENT_ID = "face-auth-bridge"

FACE_API_URL = os.getenv("FACE_API_URL", "http://localhost:8000")  # "http://localhost:8000" for Docker/Windows
PERSONS_DIR = os.getenv("PERSONS_DIR", "persons")  # "persons" for Windows, "/data/persons" for Docker
CAPTURES_DIR = os.getenv("CAPTURES_DIR", "captures")  # "captures" for Windows, "/data/caps" for Docker

# MQTT Topics
TOPIC_REQUEST = "home/auth/face/request"
TOPIC_RESPONSE = "home/auth/face/response"
TOPIC_STATUS = "home/auth/face/status"

def publish_status(client, status, message=""):
    """Publish status update to MQTT"""
    payload = {
        "status": status,
        "message": message,
        "timestamp": time.time()
    }
    client.publish(TOPIC_STATUS, json.dumps(payload))
    print(f"[STATUS] {status}: {message}")

def on_connect(client, userdata, flags, rc):
    """Callback when connected to MQTT broker"""
    if rc == 0:
        print(f"[MQTT] Connected to broker at {MQTT_BROKER}:{MQTT_PORT}")
        client.subscribe(TOPIC_REQUEST)
        print(f"[MQTT] Subscribed to {TOPIC_REQUEST}")
        publish_status(client, "ready", "Face authentication service ready")
    else:
        print(f"[MQTT] Connection failed with code {rc}")

def on_message(client, userdata, msg):
    """Callback when message received on subscribed topic"""
    try:
        print(f"[MQTT] Received message on {msg.topic}")
        request_data = json.loads(msg.payload.decode())
        print(f"[REQUEST] {request_data}")
        
        # Extract parameters
        user_id = request_data.get("userId", "unknown")
        request_id = request_data.get("requestId", str(time.time()))
        
        # Don't send "initializing" from bridge - let the backend send it
        # This ensures proper timing: backend sends it right before camera init
        
        # Call face detection REST API
        print(f"[API] Calling face detection service...")
        try:
            response = requests.post(
                f"{FACE_API_URL}/detect-webcam",
                data={
                    "persons_dir": PERSONS_DIR,
                    "webcam": "0",
                    "max_seconds": "8",
                    "stop_on_first": "true",
                    "model": "hog",
                    "tolerance": "0.6",
                    "frame_stride": "1",
                    "annotated_dir": CAPTURES_DIR,
                },
                timeout=35  # Increased timeout: camera init (up to 20s) + scan (8s) + processing (7s buffer)
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"[API] Detection result: {result}")
                
                # Extract detected persons from names_seen (excludes "Unknown")
                detected_persons = []
                if "names_seen" in result and result["names_seen"]:
                    # names_seen is a dict like {'person_name': count}
                    detected_persons = list(result["names_seen"].keys())
                
                # Determine authentication result
                if detected_persons:
                    # Found known face
                    detected_name = detected_persons[0]  # Take first match
                    publish_status(client, "success", f"Face recognized: {detected_name}")
                    
                    auth_response = {
                        "success": True,
                        "requestId": request_id,
                        "userId": detected_name,
                        "confidence": 0.95,  # TODO: Get actual confidence from API
                        "timestamp": time.time(),
                        "message": f"Welcome, {detected_name}!"
                    }
                else:
                    # No known face found
                    publish_status(client, "failed", "No recognized face detected")
                    
                    auth_response = {
                        "success": False,
                        "requestId": request_id,
                        "error": "No recognized face detected",
                        "timestamp": time.time()
                    }
                
                # Publish response
                client.publish(TOPIC_RESPONSE, json.dumps(auth_response))
                print(f"[RESPONSE] {auth_response}")
                
                # Release camera after authentication completes
                try:
                    release_response = requests.post(f"{FACE_API_URL}/camera/release", timeout=5)
                    if release_response.status_code == 200:
                        print(f"[CAMERA] {release_response.json().get('message', 'Released')}")
                    else:
                        print(f"[CAMERA] Release failed: {release_response.status_code}")
                except Exception as cam_err:
                    print(f"[CAMERA] Release error: {cam_err}")
                
            else:
                # API error
                error_msg = f"Face detection API error: {response.status_code}"
                print(f"[ERROR] {error_msg}")
                publish_status(client, "error", error_msg)
                
                auth_response = {
                    "success": False,
                    "requestId": request_id,
                    "error": error_msg,
                    "timestamp": time.time()
                }
                client.publish(TOPIC_RESPONSE, json.dumps(auth_response))
                
        except requests.exceptions.Timeout:
            error_msg = "Face detection timeout"
            print(f"[ERROR] {error_msg}")
            publish_status(client, "error", error_msg)
            
            auth_response = {
                "success": False,
                "requestId": request_id,
                "error": error_msg,
                "timestamp": time.time()
            }
            client.publish(TOPIC_RESPONSE, json.dumps(auth_response))
            
            # Release camera on timeout
            try:
                requests.post(f"{FACE_API_URL}/camera/release", timeout=5)
                print(f"[CAMERA] Released after timeout")
            except:
                pass
            
        except Exception as e:
            error_msg = f"Face detection error: {str(e)}"
            print(f"[ERROR] {error_msg}")
            publish_status(client, "error", error_msg)
            
            auth_response = {
                "success": False,
                "requestId": request_id,
                "error": error_msg,
                "timestamp": time.time()
            }
            client.publish(TOPIC_RESPONSE, json.dumps(auth_response))
            
            # Release camera on error
            try:
                requests.post(f"{FACE_API_URL}/camera/release", timeout=5)
                print(f"[CAMERA] Released after error")
            except:
                pass
            
    except Exception as e:
        print(f"[ERROR] Message processing error: {e}")

def main():
    """Main function"""
    print(f"[BRIDGE] Starting Face Authentication MQTT Bridge")
    print(f"[BRIDGE] MQTT Broker: {MQTT_BROKER}:{MQTT_PORT}")
    print(f"[BRIDGE] Face API: {FACE_API_URL}")
    print(f"[BRIDGE] Persons Dir: {PERSONS_DIR}")
    print(f"[BRIDGE] Captures Dir: {CAPTURES_DIR}")
    
    # Create MQTT client (paho-mqtt 2.0+ requires callback_api_version)
    client = mqtt_client.Client(
        client_id=CLIENT_ID,
        callback_api_version=mqtt_client.CallbackAPIVersion.VERSION1
    )
    client.on_connect = on_connect
    client.on_message = on_message
    
    # Connect to broker
    try:
        client.connect(MQTT_BROKER, MQTT_PORT)
        print(f"[MQTT] Connecting to broker...")
        
        # Start loop
        client.loop_forever()
        
    except KeyboardInterrupt:
        print("\n[BRIDGE] Shutting down...")
        client.disconnect()
    except Exception as e:
        print(f"[ERROR] Connection error: {e}")

if __name__ == "__main__":
    main()
