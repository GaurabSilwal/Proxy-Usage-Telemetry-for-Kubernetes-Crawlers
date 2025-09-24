#!/bin/bash

echo "🔍 Troubleshooting Deployment Issues"
echo "===================================="

# Check cluster status
echo "1. Cluster Status:"
kubectl cluster-info
echo ""

# Check namespaces
echo "2. Namespaces:"
kubectl get namespaces
echo ""

# Check Istio installation
echo "3. Istio Status:"
kubectl get pods -n istio-system
echo ""

# Check if Istio injection is enabled
echo "4. Istio Injection:"
kubectl get namespace crawlers -o jsonpath='{.metadata.labels.istio-injection}'
echo ""

# Check Helm releases
echo "5. Helm Releases:"
helm list -A
echo ""

# Check pod status in all namespaces
echo "6. Pod Status:"
kubectl get pods -A | grep -E "(monitoring|crawlers|istio-system)"
echo ""

# Check events for errors
echo "7. Recent Events (errors only):"
kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' | tail -10
echo ""

# Check resource usage
echo "8. Node Resources:"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
echo ""

# Suggest fixes
echo "🛠️  Common Fixes:"
echo "- If Istio pods are pending: minikube start --memory=8192 --cpus=4"
echo "- If timeout errors: Increase --timeout in deploy.sh"
echo "- If image pull errors: eval \$(minikube docker-env) && make build"
echo "- If persistent volume errors: Use minikube addons enable default-storageclass"