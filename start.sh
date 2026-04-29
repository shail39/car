#!/bin/bash
set -e

echo "Starting CarManager backend..."
cd "$(dirname "$0")/backend"
go build -o carmanager ./cmd/main.go
./carmanager &
BACKEND_PID=$!

echo "Backend running (PID $BACKEND_PID) on http://localhost:8080"
echo "Starting Flutter web..."
cd ../frontend
flutter run -d chrome --web-port 3000

kill $BACKEND_PID 2>/dev/null || true
