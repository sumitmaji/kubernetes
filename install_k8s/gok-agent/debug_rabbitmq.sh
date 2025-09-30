#!/bin/bash

# RabbitMQ Connectivity Debugging Tool for GOK-Agent
# This script helps diagnose RabbitMQ connection issues in Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

print_section() {
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

# Configuration
RABBITMQ_NAMESPACE="rabbitmq"
CONTROLLER_NAMESPACE="gok-controller"
CONTROLLER_APP_LABEL="app=web-controller"
AGENT_NAMESPACE="skmaji1"  # Update this as needed
AGENT_APP_LABEL="app=agent-backend"  # Update this as needed

print_header "🐰 RabbitMQ Connectivity Debugging Tool"
echo "This script will help diagnose RabbitMQ connection issues for GOK-Agent"
echo ""

# Step 1: Check RabbitMQ Service and Pods
print_header "Step 1: RabbitMQ Service Status"
print_section "Checking RabbitMQ pods and services..."

if kubectl get namespace $RABBITMQ_NAMESPACE &>/dev/null; then
    print_success "RabbitMQ namespace '$RABBITMQ_NAMESPACE' exists"
    
    echo ""
    print_section "RabbitMQ Pods Status:"
    kubectl get pods -n $RABBITMQ_NAMESPACE -o wide
    
    echo ""
    print_section "RabbitMQ Services:"
    kubectl get svc -n $RABBITMQ_NAMESPACE -o wide
    
    # Get RabbitMQ service IP
    RABBITMQ_IP=$(kubectl get svc rabbitmq -n $RABBITMQ_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || kubectl get svc rabbitmq -n $RABBITMQ_NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "Not found")
    print_section "RabbitMQ Service IP: $RABBITMQ_IP"
    
else
    print_error "RabbitMQ namespace '$RABBITMQ_NAMESPACE' does not exist!"
    exit 1
fi

# Step 2: Check Controller Status
print_header "Step 2: Controller Status"
print_section "Checking GOK-Agent Controller..."

if kubectl get namespace $CONTROLLER_NAMESPACE &>/dev/null; then
    print_success "Controller namespace '$CONTROLLER_NAMESPACE' exists"
    
    echo ""
    print_section "Controller Pods:"
    kubectl get pods -n $CONTROLLER_NAMESPACE -l $CONTROLLER_APP_LABEL -o wide
    
    # Get controller pod name
    CONTROLLER_POD=$(kubectl get pods -n $CONTROLLER_NAMESPACE -l $CONTROLLER_APP_LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$CONTROLLER_POD" ]]; then
        print_success "Found controller pod: $CONTROLLER_POD"
        
        echo ""
        print_section "Controller Environment Variables (RabbitMQ related):"
        kubectl exec -n $CONTROLLER_NAMESPACE $CONTROLLER_POD -c api -- env | grep -i rabbitmq || print_warning "No RabbitMQ environment variables found"
        
    else
        print_error "No controller pod found with label '$CONTROLLER_APP_LABEL'"
    fi
else
    print_error "Controller namespace '$CONTROLLER_NAMESPACE' does not exist!"
fi

# Step 3: DNS Resolution Tests
print_header "Step 3: DNS Resolution Tests"

if [[ -n "$CONTROLLER_POD" ]]; then
    print_section "Testing DNS resolution from controller pod..."
    
    echo ""
    print_section "Test 1: Short DNS name (rabbitmq.rabbitmq)"
    if kubectl exec -n $CONTROLLER_NAMESPACE $CONTROLLER_POD -c api -- python3 -c "
import socket
try:
    ip = socket.gethostbyname('rabbitmq.rabbitmq')
    print(f'✅ Success: rabbitmq.rabbitmq → {ip}')
except Exception as e:
    print(f'❌ Failed: {e}')
    exit(1)
" 2>/dev/null; then
        print_success "Short DNS name resolution: WORKING"
    else
        print_error "Short DNS name resolution: FAILED"
    fi
    
    echo ""
    print_section "Test 2: Full FQDN (rabbitmq.rabbitmq.svc.cluster.local)"
    if kubectl exec -n $CONTROLLER_NAMESPACE $CONTROLLER_POD -c api -- python3 -c "
import socket
try:
    ip = socket.gethostbyname('rabbitmq.rabbitmq.svc.cluster.local')
    print(f'✅ Success: rabbitmq.rabbitmq.svc.cluster.local → {ip}')
except Exception as e:
    print(f'❌ Failed: {e}')
    print('This is often normal - short names usually work better')
" 2>/dev/null; then
        print_success "Full FQDN resolution: WORKING"
    else
        print_warning "Full FQDN resolution: FAILED (often normal)"
    fi
    
    echo ""
    print_section "Test 3: Cluster.uat suffix (rabbitmq.rabbitmq.svc.cluster.uat)"
    if kubectl exec -n $CONTROLLER_NAMESPACE $CONTROLLER_POD -c api -- python3 -c "
import socket
try:
    ip = socket.gethostbyname('rabbitmq.rabbitmq.svc.cluster.uat')
    print(f'✅ Success: rabbitmq.rabbitmq.svc.cluster.uat → {ip}')
except Exception as e:
    print(f'❌ Failed: {e}')
    print('This is often normal - try short name instead')
" 2>/dev/null; then
        print_success "Cluster.uat FQDN resolution: WORKING"
    else
        print_warning "Cluster.uat FQDN resolution: FAILED (try short name)"
    fi
    
else
    print_error "Cannot perform DNS tests - no controller pod available"
fi

# Step 4: Network Connectivity Tests
print_header "Step 4: Network Connectivity Tests"

if [[ -n "$CONTROLLER_POD" ]]; then
    print_section "Testing network connectivity to RabbitMQ..."
    
    echo ""
    print_section "Test 1: Connection to rabbitmq.rabbitmq:5672"
    if kubectl exec -n $CONTROLLER_NAMESPACE $CONTROLLER_POD -c api -- python3 -c "
import socket
import sys
try:
    print('Testing connection to rabbitmq.rabbitmq:5672...')
    s = socket.socket()
    s.settimeout(5)
    s.connect(('rabbitmq.rabbitmq', 5672))
    print('✅ Successfully connected to RabbitMQ!')
    s.close()
except Exception as e:
    print(f'❌ Connection failed: {e}')
    sys.exit(1)
" 2>/dev/null; then
        print_success "RabbitMQ connectivity: WORKING"
    else
        print_error "RabbitMQ connectivity: FAILED"
    fi
    
    if [[ "$RABBITMQ_IP" != "Not found" ]]; then
        echo ""
        print_section "Test 2: Connection to RabbitMQ service IP ($RABBITMQ_IP:5672)"
        if kubectl exec -n $CONTROLLER_NAMESPACE $CONTROLLER_POD -c api -- python3 -c "
import socket
import sys
try:
    print('Testing connection to $RABBITMQ_IP:5672...')
    s = socket.socket()
    s.settimeout(5)
    s.connect(('$RABBITMQ_IP', 5672))
    print('✅ Successfully connected to RabbitMQ via IP!')
    s.close()
except Exception as e:
    print(f'❌ Connection failed: {e}')
    sys.exit(1)
" 2>/dev/null; then
            print_success "RabbitMQ IP connectivity: WORKING"
        else
            print_error "RabbitMQ IP connectivity: FAILED"
        fi
    fi
    
else
    print_error "Cannot perform connectivity tests - no controller pod available"
fi

# Step 5: Check Controller Logs
print_header "Step 5: Controller Application Logs"

if [[ -n "$CONTROLLER_POD" ]]; then
    print_section "Recent controller logs (last 20 lines):"
    echo ""
    kubectl logs -n $CONTROLLER_NAMESPACE $CONTROLLER_POD -c api --tail=20
    
    echo ""
    print_section "Checking for RabbitMQ-related errors in logs:"
    if kubectl logs -n $CONTROLLER_NAMESPACE $CONTROLLER_POD -c api --tail=100 | grep -i "rabbitmq\|amqp\|pika\|gaierror" | head -10; then
        print_warning "Found RabbitMQ-related log entries (shown above)"
    else
        print_success "No obvious RabbitMQ errors in recent logs"
    fi
else
    print_error "Cannot check logs - no controller pod available"
fi

# Step 6: Agent Status (if available)
print_header "Step 6: Agent Status (Optional)"

if kubectl get namespace $AGENT_NAMESPACE &>/dev/null; then
    print_section "Checking GOK-Agent status in namespace '$AGENT_NAMESPACE'..."
    
    AGENT_PODS=$(kubectl get pods -n $AGENT_NAMESPACE -l $AGENT_APP_LABEL -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$AGENT_PODS" ]]; then
        print_success "Found agent pod(s): $AGENT_PODS"
        kubectl get pods -n $AGENT_NAMESPACE -l $AGENT_APP_LABEL -o wide
        
        # Test connectivity from first agent pod
        FIRST_AGENT=$(echo $AGENT_PODS | cut -d' ' -f1)
        echo ""
        print_section "Testing RabbitMQ connectivity from agent pod: $FIRST_AGENT"
        
        if kubectl exec -n $AGENT_NAMESPACE $FIRST_AGENT -- python3 -c "
import socket
try:
    s = socket.socket()
    s.settimeout(5)
    s.connect(('rabbitmq.rabbitmq', 5672))
    print('✅ Agent can connect to RabbitMQ!')
    s.close()
except Exception as e:
    print(f'❌ Agent connection failed: {e}')
" 2>/dev/null; then
            print_success "Agent RabbitMQ connectivity: WORKING"
        else
            print_error "Agent RabbitMQ connectivity: FAILED"
        fi
    else
        print_warning "No agent pods found with label '$AGENT_APP_LABEL'"
    fi
else
    print_warning "Agent namespace '$AGENT_NAMESPACE' not found (this is optional)"
fi

# Step 7: Configuration Recommendations
print_header "Step 7: Configuration Recommendations"

print_section "Based on the tests above, here are the recommendations:"
echo ""

echo "✅ RECOMMENDED RabbitMQ Host Configuration:"
echo "   RABBITMQ_HOST: \"rabbitmq.rabbitmq\""
echo ""

echo "❌ AVOID these configurations if they're causing issues:"
echo "   ❌ RABBITMQ_HOST: \"rabbitmq.rabbitmq.svc.cluster.local\""
echo "   ❌ RABBITMQ_HOST: \"rabbitmq.rabbitmq.svc.cluster.uat\""
echo "   ❌ RABBITMQ_HOST: \"rabbitmq-0.rabbitmq-headless.rabbitmq.svc.cloud.uat\""
echo ""

echo "🔧 To fix DNS issues in running deployments:"
echo "   kubectl patch deployment web-controller -n $CONTROLLER_NAMESPACE -p '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"api\",\"env\":[{\"name\":\"RABBITMQ_HOST\",\"value\":\"rabbitmq.rabbitmq\"}]}]}}}}'"
echo ""

echo "🔍 To check current configuration:"
echo "   kubectl exec -n $CONTROLLER_NAMESPACE <pod-name> -c api -- env | grep RABBITMQ_HOST"
echo ""

# Step 8: Summary
print_header "Step 8: Diagnostic Summary"

print_section "Debugging completed! Check the results above for:"
echo "  1. ✅ RabbitMQ service availability"
echo "  2. ✅ DNS resolution (should work with 'rabbitmq.rabbitmq')"  
echo "  3. ✅ Network connectivity on port 5672"
echo "  4. ✅ Application logs for errors"
echo "  5. ✅ Proper environment variable configuration"
echo ""

print_success "Use this script anytime you need to debug RabbitMQ connectivity issues!"
print_section "💡 Pro tip: If DNS fails but IP works, update hostname to 'rabbitmq.rabbitmq'"

echo ""
print_header "🐰 RabbitMQ Debugging Complete!"