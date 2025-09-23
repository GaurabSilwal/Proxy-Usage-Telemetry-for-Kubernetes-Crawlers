# Deployment Guide - POC Verification

## Prerequisites

- Docker Desktop installed and running
- kubectl CLI tool
- Helm 3.x
- 8GB+ RAM available for cluster

## Option 1: One-Command Setup (Recommended)

```bash
# Complete automated setup
make quick-start
```

This will:
1. Start minikube cluster
2. Install Istio service mesh
3. Build Docker images
4. Deploy monitoring stack
5. Deploy crawler simulation
6. Setup port forwarding

## Option 2: Step-by-Step Setup

### 1. Setup Local Cluster

```bash
# Start minikube
minikube start --memory=8192 --cpus=4 --kubernetes-version=v1.28.0

# Install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
istioctl install --set values.defaultRevision=default -y
cd ..
```

### 2. Build Images

```bash
# Build Docker images for minikube
eval $(minikube docker-env)
make build
```

### 3. Deploy Solution

```bash
# Deploy everything
make deploy
```

### 4. Access Dashboards

```bash
# Setup port forwarding
make port-forward

# Access dashboards:
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
```

## POC Verification Steps

### 1. Check Pod Status (2-3 minutes)

```bash
# Verify all pods are running
kubectl get pods -n monitoring
kubectl get pods -n crawlers

# Expected output:
# monitoring namespace: prometheus-server, grafana pods running
# crawlers namespace: load-generator, crawler-pods running with istio-proxy sidecars
```

### 2. Verify Metrics Collection (5 minutes)

```bash
# Check Prometheus targets
open http://localhost:9090/targets

# Verify metrics are being collected
curl -s "http://localhost:9090/api/v1/query?query=istio_requests_total" | jq '.data.result | length'
# Should return > 0
```

### 3. View Grafana Dashboard (Immediate)

```bash
# Open Grafana
open http://localhost:3000

# Login: admin/admin
# Navigate to: Dashboards > Proxy Usage Dashboard
# Verify data is showing for:
# - Request counts by vendor
# - Bandwidth usage
# - Top destinations
```

### 4. Validate Proxy Attribution (2 minutes)

```bash
# Check if proxy vendor labels are present
curl -s "http://localhost:9090/api/v1/query?query=istio_requests_total{proxy_vendor!=\"unknown\"}" | jq '.data.result[0].metric.proxy_vendor'
# Should return: "vendor-a", "vendor-b", or "vendor-c"
```

### 5. Scale Test (Optional)

```bash
# Scale up load generators
kubectl scale deployment load-generator -n crawlers --replicas=20

# Watch metrics increase in Grafana
# Verify system handles increased load
```

## Expected Results

After 5-10 minutes, you should see:

✅ **Grafana Dashboard**: Live metrics showing request counts, bandwidth usage  
✅ **Proxy Attribution**: Traffic correctly attributed to vendor-a, vendor-b, vendor-c  
✅ **Multi-Protocol**: Both HTTP and HTTPS requests tracked  
✅ **Destinations**: Top destinations like httpbin.org, jsonplaceholder.typicode.com  
✅ **Bandwidth**: Inbound/outbound bytes per proxy vendor  

## Troubleshooting

### Pods Not Starting
```bash
# Check pod logs
kubectl logs -n crawlers deployment/load-generator
kubectl logs -n monitoring deployment/monitoring-stack-prometheus-server
```

### No Metrics in Grafana
```bash
# Verify Istio injection
kubectl get pods -n crawlers -o jsonpath='{.items[*].spec.containers[*].name}' | grep istio-proxy

# Check Prometheus scraping
kubectl port-forward -n monitoring svc/monitoring-stack-prometheus-server 9090:80
# Visit http://localhost:9090/targets
```

### Images Not Found
```bash
# Rebuild images in minikube context
eval $(minikube docker-env)
make build
```

## Cleanup

```bash
# Remove everything
make clean

# Stop minikube
minikube stop
minikube delete
```

## Demo Script (5-minute presentation)

```bash
# 1. Show architecture
cat README.md | grep -A 20 "Architecture Overview"

# 2. Deploy solution
make quick-start

# 3. Show live metrics
open http://localhost:3000
# Navigate to Proxy Usage Dashboard

# 4. Demonstrate scaling
kubectl scale deployment load-generator -n crawlers --replicas=10
# Show metrics increase in real-time

# 5. Show proxy attribution
curl -s "http://localhost:9090/api/v1/query?query=sum by (proxy_vendor) (rate(istio_requests_total[5m]))" | jq '.data.result'
```

## Success Criteria

The POC is successful when:
- [ ] All pods running (monitoring + crawlers namespaces)
- [ ] Grafana showing live proxy usage metrics
- [ ] Traffic correctly attributed to 3 proxy vendors
- [ ] Both HTTP/HTTPS requests tracked
- [ ] Bandwidth metrics (in/out) visible
- [ ] System scales to 20+ crawler pods
- [ ] No errors in pod logs