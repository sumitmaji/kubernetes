#!/bin/bash

# RabbitMQ Test Script
# This script automates the complete RabbitMQ testing process

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to cleanup background processes
cleanup() {
    print_status "Cleaning up background processes..."
    if [[ -n $PORT_FORWARD_PID ]]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
        print_status "Stopped port-forwarding (PID: $PORT_FORWARD_PID)"
    fi
    # Kill any remaining kubectl port-forward processes
    pkill -f "kubectl port-forward.*rabbitmq" 2>/dev/null || true
}

# Set trap to cleanup on script exit
trap cleanup EXIT

print_status "🐰 Starting RabbitMQ Test Script"
echo "=================================================="

# Step 1: Check if Python and pip are installed
print_status "Step 1: Checking Python dependencies..."
if ! command -v python3 &> /dev/null; then
    print_error "python3 is not installed. Please install Python 3."
    exit 1
fi
print_success "Python 3 is available"

# Step 2: Install pika if not already installed
print_status "Step 2: Installing/checking pika dependency..."
if ! python3 -c "import pika" &> /dev/null; then
    print_status "Installing pika..."
    pip3 install pika
    print_success "pika installed successfully"
else
    print_success "pika is already installed"
fi

# Step 3: Check if kubectl is configured
print_status "Step 3: Checking kubectl configuration..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "kubectl is not configured or cluster is not accessible"
    print_error "Please configure kubectl to access your Kubernetes cluster"
    exit 1
fi
print_success "kubectl is configured and cluster is accessible"

# Step 4: Check RabbitMQ deployment status
print_status "Step 4: Checking RabbitMQ deployment status..."
if ! kubectl get namespace rabbitmq &> /dev/null; then
    print_error "rabbitmq namespace does not exist"
    exit 1
fi

# Check if RabbitMQ pods are running
if ! kubectl get pods -n rabbitmq | grep -q "Running"; then
    print_error "RabbitMQ pods are not running"
    kubectl get pods -n rabbitmq
    exit 1
fi

print_success "RabbitMQ namespace and pods are available"

# Step 5: Check RabbitMQ service
print_status "Step 5: Checking RabbitMQ service..."
if ! kubectl get svc rabbitmq -n rabbitmq &> /dev/null; then
    print_error "RabbitMQ service not found"
    exit 1
fi

print_success "RabbitMQ service is available"
kubectl get pods,svc -n rabbitmq

# Step 6: Kill any existing port-forward processes
print_status "Step 6: Cleaning up any existing port-forwarding..."
pkill -f "kubectl port-forward.*rabbitmq" 2>/dev/null || true
sleep 2

# Step 7: Set up port forwarding
print_status "Step 7: Setting up port-forwarding to RabbitMQ..."
kubectl port-forward svc/rabbitmq 5672:5672 -n rabbitmq > /dev/null 2>&1 &
PORT_FORWARD_PID=$!

print_success "Port-forwarding started (PID: $PORT_FORWARD_PID)"
print_status "Waiting for port-forwarding to establish..."
sleep 3

# Step 8: Verify port-forwarding is working
print_status "Step 8: Verifying port-forwarding..."
if ! ps -p $PORT_FORWARD_PID > /dev/null; then
    print_error "Port-forwarding process died"
    exit 1
fi
print_success "Port-forwarding is active"

# Step 9: Test port connectivity (optional)
print_status "Step 9: Testing port connectivity..."
if command -v nc &> /dev/null; then
    if timeout 5 nc -z localhost 5672; then
        print_success "Port 5672 is accessible"
    else
        print_warning "Could not verify port accessibility, but continuing..."
    fi
else
    print_status "netcat not available, skipping port test"
fi

# Step 10: Run the RabbitMQ test
print_status "Step 10: Running RabbitMQ test program..."
echo ""
print_status "=========================================="
print_status "       RABBITMQ TEST EXECUTION"
print_status "=========================================="
echo ""

if python3 rabbitmq_test.py; then
    echo ""
    print_success "🎉 RabbitMQ test completed successfully!"
    print_success "✅ Message publishing and consuming worked correctly"
    print_success "✅ Topic exchange routing is functioning properly"
else
    echo ""
    print_error "❌ RabbitMQ test failed"
    exit 1
fi

# Step 11: Display summary
echo ""
print_status "=========================================="
print_status "           TEST SUMMARY"
print_status "=========================================="
print_success "✅ Dependencies installed and verified"
print_success "✅ Kubernetes cluster connectivity confirmed" 
print_success "✅ RabbitMQ deployment is healthy"
print_success "✅ Port-forwarding established successfully"
print_success "✅ RabbitMQ messaging test passed"
print_success "✅ Topic exchange functionality verified"
echo ""
print_status "🐰 All RabbitMQ tests completed successfully!"
print_status "Port-forwarding will be cleaned up automatically."

# Cleanup happens automatically via trap