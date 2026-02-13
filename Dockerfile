# Cloud Run 用 Python イメージ（PORT はランタイムで設定される）
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
ENV PORT=8080

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# gunicorn で 0.0.0.0:PORT にバインド（Cloud Run が PORT を注入）
CMD exec gunicorn --bind 0.0.0.0:${PORT} --workers 1 --threads 8 app:app
