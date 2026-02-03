#!/bin/bash

# Start native upscaling service (without Docker)

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting Video Upscaler (Native Mode)${NC}"
echo

# Check if .venv exists
if [ ! -d ".venv" ]; then
    echo "Virtual environment not found. Creating..."
    python3 -m venv .venv
    echo "Installing Python dependencies..."
    .venv/bin/pip install -r worker/requirements.txt
fi

# Start Next.js web app in background
echo -e "${GREEN}Starting Next.js web app on port 3000...${NC}"
STORAGE_ROOT="./storage" npm run dev &
WEB_PID=$!

# Wait for web app to be ready
sleep 3

# Start Python worker
echo -e "${GREEN}Starting Python worker with Metal acceleration...${NC}"
cd worker
STORAGE_ROOT="../storage" "../.venv/bin/python" main.py &
WORKER_PID=$!
cd ..

echo
echo -e "${GREEN}✓ Services started!${NC}"
echo "  Web:    http://localhost:3000"
echo "  Worker: Running with Metal GPU acceleration"
echo
echo "Press Ctrl+C to stop all services"
echo

# Handle Ctrl+C
trap "echo; echo 'Stopping services...'; kill $WEB_PID $WORKER_PID 2>/dev/null; exit" INT

# Wait for processes
wait
