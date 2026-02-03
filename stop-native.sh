#!/bin/bash

# Stop all running services

pkill -f "next dev" 2>/dev/null
pkill -f "worker/main.py" 2>/dev/null
pkill -f "python.*main.py" 2>/dev/null

echo "All services stopped."
