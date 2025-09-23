#!/bin/bash

set -e

echo "Deploying proxy monitoring solution..."

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Build Helm dependencies for local charts
helm dependency build ./helm/monitoring-stack
helm dependency build ./helm/crawler-simulation

# Create namespaces
echo "Creating namespaces..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace crawlers --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -

# Enable Istio injection for crawlers namespace
echo "Enabling Istio injection..."
kubectl label namespace crawlers istio-injection=enabled --overwrite

# Install Istio directly from the Helm repo
echo "Installing Istio base, control plane, and gateway..."
helm upgrade --install istio-base istio/base -n istio-system --create-namespace --wait
helm upgrade --install istiod istio/istiod -n istio-system --wait
# helm upgrade --install istio-ingressgateway istio/gateway -n istio-system --wait

# Install monitoring stack
echo "Installing monitoring stack..."
helm upgrade --install monitoring-stack ./helm/monitoring-stack \
  -n monitoring \
  --wait \
  --timeout=10m

# Install crawler simulation
echo "Installing crawler simulation..."
helm upgrade --install crawler-simulation ./helm/crawler-simulation \
  -n crawlers \
  --wait \
  --timeout=5m

echo "Deployment completed successfully!"
echo ""
echo "Access instructions:"
echo "1. Grafana Dashboard:"
echo "   kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80"
echo "   Open http://localhost:3000 (admin/admin)"
echo ""
echo "2. Prometheus:"
echo "   kubectl port-forward -n monitoring svc/monitoring-stack-prometheus-server 9090:80"
echo "   Open http://localhost:9090"
echo ""
echo "3. Check pod status:"
echo "   kubectl get pods -n crawlers"
echo "   kubectl get pods -n monitoring"
echo "   kubectl get pods -n istio-system"
