#!/usr/bin/env python3
"""Fix asr-fastwhisper to use auto-download model instead of local path."""

path = '/home/sapper/project/grad_project_backend/docker-compose.yml'
with open(path) as f:
    content = f.read()

# Change WHISPER_MODEL from local path to auto-download name
content = content.replace(
    '- WHISPER_MODEL=/models/whisper-medium  # local model path (see instructions)',
    '- WHISPER_MODEL=small  # auto-download from HuggingFace'
)

# Comment out the model volume mount
content = content.replace(
    '      - ./models/whisper-medium:/models/whisper-medium:ro',
    '      # - ./models/whisper-medium:/models/whisper-medium:ro  # not needed with auto-download'
)

with open(path, 'w') as f:
    f.write(content)
print('docker-compose.yml updated: asr-fastwhisper model set to auto-download')
