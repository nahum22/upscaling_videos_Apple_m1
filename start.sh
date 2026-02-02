#!/bin/bash

# Video Upscaling Application Startup Script

echo "Starting Video Upscaling Application..."
echo "========================================"

cd "$(dirname "$0")"

# Stop any running containers
docker compose down 2>/dev/null

# Start services
docker compose --profile cpu up

echo ""
echo "Application stopped."
