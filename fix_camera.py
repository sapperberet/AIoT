#!/usr/bin/env python3
"""Create docker-compose.override.yml to fix camera-publisher for WSL (no /dev/video0)"""

override = """# Override for WSL: replace real camera with a test-pattern stream
services:
  camera-publisher:
    devices: []
    group_add: []
    environment:
      CAM_DEVICE: /dev/video0
      CAM_SIZE: 1280x720
      CAM_FPS: "10"
      ENCODER: libx264
      BITRATE: 1500k
      RTSP_URL: rtsp://mediamtx:8554/cam
    entrypoint: ["/bin/sh", "-c"]
    command:
      - |
        echo "No camera device – publishing colour-bars test stream";
        exec ffmpeg -re -f lavfi -i testsrc=size=1280x720:rate=10 \\
          -f lavfi -i sine=frequency=440:sample_rate=44100 \\
          -vcodec libx264 -preset ultrafast -tune zerolatency \\
          -b:v 1500k -g 20 \\
          -acodec aac -b:a 64k \\
          -f rtsp rtsp://mediamtx:8554/cam
"""

path = '/home/sapper/project/grad_project_backend/docker-compose.override.yml'
with open(path, 'w') as f:
    f.write(override)
print(f'Written {path}')
