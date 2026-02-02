#!/bin/bash

# Video Upscaling Application Startup Script

echo "Starting Video Upscaling Application..."
echo "========================================"

cd "$(dirname "$0")"

# Stop any running containers and remove volumes
docker compose down -v 2>/dev/null

# Remove any orphaned containers
docker container prune -f > /dev/null 2>&1

# Clean up stale Docker networks
docker network prune -f > /dev/null 2>&1

# Start services
docker compose --profile cpu up

echo ""
echo "Application stopped."
