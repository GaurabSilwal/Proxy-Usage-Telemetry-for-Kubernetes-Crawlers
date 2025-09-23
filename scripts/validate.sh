#!/bin/bash

set -e

echo "Validating proxy monitoring solution..."

# Check if namespaces exist
echo "Checking namespaces..."
kubectl get namespace monitoring crawlers

# Check if Istio injection is enabled
echo "Checking Istio injection..."
kubectl get namespace crawlers -o jsonpath='{.metadata.labels.istio-injection}'

# Check pod status
echo "Checking pod status..."
echo "Monitoring pods:"
kubectl get pods -n monitoring
echo ""
echo "Crawler pods:"
kubectl get pods -n crawlers

# Check if metrics are being collected
echo "Checking Prometheus targets..."
kubectl port-forward -n monitoring svc/monitoring-stack-prometheus-server 9090:80 &
PROM_PID=$!
sleep 5

# Test Prometheus API
echo "Testing Prometheus metrics..."
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="istio-mesh") | .health' || echo "Prometheus not ready yet"

# Kill port-forward
kill $PROM_PID 2>/dev/null || true

# Check Grafana
echo "Testing Grafana..."
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80 &
GRAFANA_PID=$!
sleep 5

curl -s http://localhost:3000/api/health | jq '.database' || echo "Grafana not ready yet"

# Kill port-forward
kill $GRAFANA_PID 2>/dev/null || true

# Check if load is being generated
echo "Checking load generator logs..."
kubectl logs -n crawlers deployment/load-generator --tail=10

echo "Validation completed!"
echo ""
echo "Manual verification steps:"
echo "1. Check Grafana dashboard at http://localhost:3000"
echo "2. Verify metrics in Prometheus at http://localhost:9090"
echo "3. Check Istio proxy status: istioctl proxy-status"