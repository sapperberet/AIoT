#!/usr/bin/env python3
"""
Simple UDP broadcast receiver to test if beacon broadcasts are reaching the network.
This binds to port 18830 and listens for any incoming UDP packets.
"""
import socket
import time

BEACON_PORT = 18830

print(f"[TEST] Listening for UDP broadcasts on 0.0.0.0:{BEACON_PORT}")
print("[TEST] This will show if beacon broadcasts are being sent on the network")
print("[TEST] Press Ctrl+C to stop\n")

try:
    # Create UDP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    # Bind to the beacon port
    sock.bind(("0.0.0.0", BEACON_PORT))
    sock.settimeout(5.0)
    
    print(f"[TEST] ✅ Successfully bound to port {BEACON_PORT}")
    print(f"[TEST] ⏳ Waiting for broadcasts...\n")
    
    packet_count = 0
    while True:
        try:
            data, addr = sock.recvfrom(1024)
            packet_count += 1
            message = data.decode()
            print(f"[TEST] 📦 Packet #{packet_count} from {addr[0]}:{addr[1]}")
            print(f"[TEST] 📨 Content: {message}\n")
        except socket.timeout:
            print(f"[TEST] ⏳ No packets received in last 5 seconds... (total: {packet_count})")
        except KeyboardInterrupt:
            break
except Exception as e:
    print(f"[TEST] ❌ Error: {e}")
    print("\nPossible issues:")
    print("1. Port 18830 is already in use (by beacon container)")
    print("2. Permission denied")
    print("\nTo fix: Stop the beacon container first:")
    print("   docker-compose stop broker-beacon")
finally:
    print("\n[TEST] Stopped")
