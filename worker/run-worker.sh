#!/bin/bash

# Run worker with GPU support (outside Docker)

cd "$(dirname "$0")"

echo "Setting up Python environment for GPU worker..."

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required but not found"
    exit 1
fi

# Create venv if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate venv
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Set storage root to parent directory
export STORAGE_ROOT="$(pwd)/../storage"

echo ""
echo "Starting worker with GPU support..."
echo "Storage root: $STORAGE_ROOT"
echo ""

python main.py
