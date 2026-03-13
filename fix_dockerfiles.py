#!/usr/bin/env python3
"""Fix Dockerfiles to use CPU-only PyTorch (smaller download, avoids timeout)"""

body_dockerfile = r"""FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libgl1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --retries 5 --timeout 300 torch torchvision --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir --retries 5 --timeout 300 -r requirements.txt

COPY app.py .

EXPOSE 8040

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8040"]
"""

ocr_dockerfile = r"""FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libgl1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --retries 5 --timeout 300 torch torchvision --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir --retries 5 --timeout 300 -r requirements.txt

COPY app.py .

EXPOSE 8030

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8030"]
"""

with open('/home/sapper/project/grad_project_backend/CV/body-detection/Dockerfile', 'w') as f:
    f.write(body_dockerfile.lstrip('\n'))
print('body-detection Dockerfile written OK')

with open('/home/sapper/project/grad_project_backend/CV/ocr/Dockerfile', 'w') as f:
    f.write(ocr_dockerfile.lstrip('\n'))
print('ocr Dockerfile written OK')
