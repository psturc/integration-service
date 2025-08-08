#!/bin/sh
set -e

term_handler() {
  echo "SIGTERM received — shutting down integration-service gracefully..."

  echo "Stopping app process (PID: $APP_PID)..."
  kill "$APP_PID"
  echo "PID $APP_PID killed..."

  # Wait for the process to actually finish
  echo "Waiting for manager-go to finish graceful shutdown..."
  wait "$APP_PID" 2>/dev/null || true
  
  echo "operator process has exited"

  sleep 10
  exit 0
}

trap term_handler TERM INT

echo "Starting integration-service..."
./manager-go "$@" &
APP_PID=$!

echo "manager-go APP_PID: $APP_PID"

wait "$APP_PID"