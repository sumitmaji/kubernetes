#!/bin/bash
# Installation script for Service Template Generator

set -e

echo "=== Service Template Generator Installation ==="

# Check Python installation
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not installed."
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
REQUIRED_VERSION="3.8"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "Error: Python 3.8+ is required. Found: $PYTHON_VERSION"
    exit 1
fi

echo "✓ Python $PYTHON_VERSION found"

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install -r requirements.txt

# Make scripts executable
echo "Setting up permissions..."
chmod +x generate_service.py

# Create symlink for global access (optional)
read -p "Create global command 'generate-service'? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    sudo ln -sf "$SCRIPT_DIR/generate_service.py" /usr/local/bin/generate-service
    echo "✓ Global command 'generate-service' created"
fi

# Test the installation
echo "Testing installation..."
python3 generate_service.py --create-sample

if [ -f "sample_service_config.yaml" ]; then
    echo "✓ Installation test passed"
    echo ""
    echo "=== Installation Complete ==="
    echo ""
    echo "Usage examples:"
    echo "  python3 generate_service.py --config sample_service_config.yaml"
    echo "  python3 generate_service.py --service-name my-service --backend python --frontend reactjs"
    if command -v generate-service &> /dev/null; then
        echo "  generate-service --config sample_service_config.yaml"
    fi
    echo ""
    echo "Sample configuration created: sample_service_config.yaml"
    echo "Templates directory: templates/"
    echo "Generated services will be created in: generated_services/"
else
    echo "✗ Installation test failed"
    exit 1
fi