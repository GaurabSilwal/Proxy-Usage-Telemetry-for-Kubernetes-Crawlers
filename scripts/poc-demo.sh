#!/bin/bash

set -e

echo "🚀 Starting Proxy Usage Observability POC Demo"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}📋 Step $1: $2${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Prerequisites Check
print_step "1" "Checking Prerequisites"

if ! command -v docker &> /dev/null; then
    print_error "Docker not found. Please install Docker Desktop."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    print_error "Helm not found. Please install Helm 3.x."
    exit 1
fi

if ! command -v minikube &> /dev/null; then
    print_error "minikube not found. Please install minikube."
    exit 1
fi

print_success "All prerequisites found"

# Step 2: Start Cluster
print_step "2" "Starting Minikube Cluster (this may take 2-3 minutes)"

if minikube status | grep -q "Running"; then
    print_warning "Minikube already running"
else
    minikube start --memory=8192 --cpus=4 --kubernetes-version=v1.28.0
    print_success "Minikube cluster started"
fi

# Step 3: Install Istio
print_step "3" "Installing Istio Service Mesh"

if kubectl get namespace istio-system &> /dev/null; then
    print_warning "Istio already installed"
else
    curl -L https://istio.io/downloadIstio | sh -
    cd istio-*
    export PATH=$PWD/bin:$PATH
    istioctl install --set values.defaultRevision=default -y
    kubectl label namespace default istio-injection=enabled
    cd ..
    print_success "Istio installed successfully"
fi

# Step 4: Build Images
print_step "4" "Building Docker Images"

eval $(minikube docker-env)
make build
print_success "Docker images built"

# Step 5: Deploy Solution
print_step "5" "Deploying Monitoring Solution"

make deploy
print_success "Solution deployed"

# Step 6: Wait for Pods
print_step "6" "Waiting for Pods to be Ready (2-3 minutes)"

echo "Waiting for monitoring pods..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

echo "Waiting for crawler pods..."
kubectl wait --for=condition=ready pod -l app=load-generator -n crawlers --timeout=300s
kubectl wait --for=condition=ready pod -l app=crawler -n crawlers --timeout=300s

print_success "All pods are ready"

# Step 7: Setup Port Forwarding
print_step "7" "Setting up Port Forwarding"

# Kill any existing port forwards
pkill -f "kubectl port-forward" 2>/dev/null || true

# Start port forwarding in background
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80 &
kubectl port-forward -n monitoring svc/monitoring-stack-prometheus-server 9090:80 &

sleep 5
print_success "Port forwarding active"

# Step 8: Verification
print_step "8" "Running POC Verification"

echo "Checking pod status..."
kubectl get pods -n monitoring
kubectl get pods -n crawlers

echo ""
echo "Checking metrics collection..."
sleep 10  # Wait for metrics to start flowing

# Test Prometheus
if curl -s http://localhost:9090/api/v1/targets | grep -q "istio"; then
    print_success "Prometheus is collecting Istio metrics"
else
    print_warning "Prometheus metrics not ready yet (may take 1-2 more minutes)"
fi

# Test Grafana
if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    print_success "Grafana is healthy"
else
    print_warning "Grafana not ready yet"
fi

# Step 9: Demo Instructions
print_step "9" "POC Demo Ready!"

echo ""
echo "🎯 POC VERIFICATION COMPLETE!"
echo "=============================="
echo ""
echo "📊 Access Dashboards:"
echo "   Grafana:    http://localhost:3000 (admin/admin)"
echo "   Prometheus: http://localhost:9090"
echo ""
echo "🔍 Verification Steps:"
echo "   1. Open Grafana dashboard"
echo "   2. Navigate to 'Proxy Usage Dashboard'"
echo "   3. Verify metrics for vendor-a, vendor-b, vendor-c"
echo "   4. Check bandwidth usage charts"
echo "   5. View top destinations table"
echo ""
echo "🧪 Test Scaling:"
echo "   kubectl scale deployment load-generator -n crawlers --replicas=20"
echo ""
echo "📈 Sample Queries (Prometheus):"
echo "   sum by (proxy_vendor) (rate(istio_requests_total{source_app=\"crawler\"}[5m]))"
echo "   sum by (proxy_vendor) (rate(istio_request_bytes_sum{source_app=\"crawler\"}[5m]))"
echo ""
echo "🧹 Cleanup:"
echo "   make clean"
echo "   minikube stop && minikube delete"
echo ""

# Optional: Open browsers automatically (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🌐 Opening dashboards in browser..."
    sleep 2
    open http://localhost:3000
    open http://localhost:9090
fi

print_success "POC Demo Setup Complete! 🎉"