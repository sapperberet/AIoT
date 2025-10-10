#!/usr/bin/env python3
"""
Test script to verify we can receive UDP broadcasts from the beacon.
Run this on the same machine to test beacon reception.
"""
import socket
import json
import time

BEACON_PORT = 18830

print(f"[TEST] Listening for UDP broadcasts on port {BEACON_PORT}...")
print("[TEST] Press Ctrl+C to stop")

# Create UDP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(("", BEACON_PORT))
sock.settimeout(2.0)

# Also send WHO_IS query
def send_who_is():
    tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    tx.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    msg = json.dumps({"type": "WHO_IS", "name": "face-broker"}).encode()
    tx.sendto(msg, ("255.255.255.255", BEACON_PORT))
    print(f"[TEST] Sent WHO_IS broadcast: {msg}")
    tx.close()

# Send initial WHO_IS
send_who_is()

try:
    packet_count = 0
    while True:
        try:
            data, addr = sock.recvfrom(1024)
            packet_count += 1
            print(f"\n[TEST] 📦 Packet #{packet_count} from {addr[0]}:{addr[1]}")
            try:
                message = data.decode()
                print(f"[TEST] 📨 Raw: {message}")
                beacon_data = json.loads(message)
                print(f"[TEST] ✅ Parsed: {beacon_data}")
            except Exception as e:
                print(f"[TEST] ❌ Parse error: {e}")
        except socket.timeout:
            print("[TEST] ⏳ Waiting...")
            # Re-send WHO_IS every few seconds
            send_who_is()
except KeyboardInterrupt:
    print("\n[TEST] Stopped")
finally:
    sock.close()
