#!/usr/bin/env python3
"""Comment out camera-publisher devices in docker-compose.yml for WSL."""
import re

path = '/home/sapper/project/grad_project_backend/docker-compose.yml'
with open(path) as f:
    content = f.read()

# Comment out the devices section for camera-publisher
content = content.replace(
    '    devices:\n'
    '      - "/dev/video0:/dev/video0"    # adjust if your camera index differs\n'
    '      - "/dev/dri:/dev/dri"\n'
    '    group_add:\n'
    '      - "video"',
    '    # devices:                            # commented for WSL\n'
    '    #   - "/dev/video0:/dev/video0"\n'
    '    #   - "/dev/dri:/dev/dri"\n'
    '    # group_add:\n'
    '    #   - "video"'
)

with open(path, 'w') as f:
    f.write(content)
print('docker-compose.yml updated: camera devices commented out')
