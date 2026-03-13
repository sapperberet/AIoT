#!/usr/bin/env python3
"""Remove empty volumes section from asr-fastwhisper."""

path = '/home/sapper/project/grad_project_backend/docker-compose.yml'
with open(path) as f:
    content = f.read()

# Remove the volumes key and commented line for asr-fastwhisper
content = content.replace(
    '    volumes:\n'
    '      # - ./models/whisper-medium:/models/whisper-medium:ro  # not needed with auto-download\n',
    '    # volumes:  # not needed with auto-download model\n'
    '    #   - ./models/whisper-medium:/models/whisper-medium:ro\n'
)

with open(path, 'w') as f:
    f.write(content)
print('Fixed asr-fastwhisper volumes section')
