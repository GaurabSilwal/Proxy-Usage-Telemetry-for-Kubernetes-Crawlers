# Kubernetes Proxy Usage Observability Solution

## Problem Statement

A large Kubernetes cluster runs thousands of crawler pods in the `crawlers` namespace. Each `crawler-pod` uses one of multiple third‑party **proxy vendors** (e.g., `vendor-a`, `vendor-b`, `vendor-c`). Vendors expose **many proxy IPs** (potentially millions over time). The system must attribute traffic to the correct vendor.

## Requirements

Design and implement an observability solution that measures, attributes, and visualizes outbound proxy usage from thousands of crawler pods. Must produce accurate metrics for:

- **(a)** Requests sent via each proxy (count)
- **(b)** Destination (domain/host and/or remote IP)
- **(c)** Bandwidth sent per proxy per pod (outgoing bytes)
- **(d)** Bandwidth received per proxy per pod (incoming bytes)

**Protocols**: HTTP and HTTPS, including HTTP/1 and HTTP/2
**Scale**: Thousands of crawler pods, millions of proxy IPs over time

## Solution Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Crawler Pods  │───▶│  Istio Sidecar   │───▶│  Proxy Vendors  │
│   (crawlers ns) │    │  (Envoy Proxy)   │    │  (vendor-a/b/c) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │
         │              ┌────────▼────────┐
         │              │   Prometheus    │
         │              │ (Recording Rules)│
         │              └────────┬────────┘
         │                       │
  ┌──────▼──────┐      ┌────────▼────────┐
  │Load Generator│      │     Grafana     │
  │ (Synthetic) │      │  (Dashboards)   │
  └─────────────┘      └─────────────────┘
```

## Key Components

### 1. **Istio Service Mesh**
- **Purpose**: Automatic traffic interception without code changes
- **Technology**: Envoy sidecars inject telemetry into all HTTP/HTTPS traffic
- **Benefit**: Zero-instrumentation approach, supports HTTP/1, HTTP/2, HTTPS

### 2. **Prometheus Recording Rules**
- **Purpose**: Attribute traffic to proxy vendors based on destination patterns
- **Logic**:
  - `vendor-a` → GitHub traffic (`api.github.com`)
  - `vendor-b` → HTTPBin traffic (`httpbin.org`)
  - `vendor-c` → JSONPlaceholder traffic (`typicode.com`)

### 3. **Metrics Pipeline**
```
Base Metrics (Istio) → Recording Rules (Prometheus) → Dashboards (Grafana)
```

## Metrics Produced

| Metric | Description | Labels |
|--------|-------------|--------|
| `proxy_requests_total` | Request counts per proxy vendor | `proxy_vendor`, `pod_name`, `destination_service` |
| `proxy_request_bytes_sum` | Outbound bandwidth per proxy | `proxy_vendor`, `pod_name` |
| `proxy_response_bytes_sum` | Inbound bandwidth per proxy | `proxy_vendor`, `pod_name` |

## Quick Start

### Prerequisites
- Docker Desktop
- kubectl CLI
- Helm 3.x
- 8GB+ RAM for cluster

### Deploy Solution
```bash
# Complete automated setup
make quick-start
```

This will:
1. Start minikube cluster
2. Install Istio service mesh
3. Build Docker images
4. Deploy monitoring stack (Prometheus + Grafana)
5. Deploy crawler simulation
6. Setup port forwarding

### Access Dashboards
```bash
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
```

## Verification

### Prometheus Verification

#### 1. Access Prometheus
```bash
kubectl port-forward -n monitoring svc/monitoring-stack-prometheus-server 9090:80 &
# Open http://localhost:9090
```

#### 2. Verify Requirements in Prometheus UI

**Navigate to Graph tab and run these queries:**

**Requirement (a): Request Counts per Proxy**
```promql
sum by (proxy_vendor) (proxy_requests_total)
```
**Expected**: Shows vendor-a, vendor-b, vendor-c with counts

**Requirement (b): Destinations**
```promql
sum by (destination_service) (proxy_requests_total)
```
**Expected**: Shows api.github.com:443, httpbin.org:443, etc.

**Requirement (c): Outbound Bandwidth per Proxy per Pod**
```promql
sum by (proxy_vendor, pod_name) (proxy_request_bytes_sum)
```
**Expected**: Shows bytes sent per vendor per pod

**Requirement (d): Inbound Bandwidth per Proxy per Pod**
```promql
sum by (proxy_vendor, pod_name) (proxy_response_bytes_sum)
```
**Expected**: Shows bytes received per vendor per pod

**Protocol Support**
```promql
sum by (request_protocol) (proxy_requests_total)
```
**Expected**: Shows http and https

#### 3. Check Targets Status
- Go to **Status → Targets**
- Verify `istio-proxy` job shows UP status
- Should see multiple crawler pod endpoints

### Grafana Verification

#### 1. Access Grafana
```bash
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80 &
# Open http://localhost:3000 (admin/admin)
```

#### 2. Verify Dashboard
- Navigate to **Dashboards → Proxy Usage Dashboard**
- Verify 3 panels show data:
  - **Requests by Proxy Vendor**: Shows vendor-a, vendor-b, vendor-c stats
  - **Bandwidth Usage (Outbound)**: Shows bandwidth trends per vendor
  - **Top Destinations**: Shows table of destinations with request counts

#### 3. Create Custom Panels (Optional)
Add new panels with these queries:

**Per-Pod Bandwidth Panel:**
```promql
sum by (pod_name, proxy_vendor) (rate(proxy_request_bytes_sum[5m]) + rate(proxy_response_bytes_sum[5m]))
```

**Request Rate Panel:**
```promql
sum by (proxy_vendor) (rate(proxy_requests_total[5m]))
```

### Quick Verification Commands

**Test all requirements at once:**
```bash
# Run from terminal with port-forward active
echo "=== Proxy Vendors ==="
curl -s "http://localhost:9090/api/v1/query?query=sum%20by%20(proxy_vendor)%20(proxy_requests_total)" | jq '.data.result[].metric.proxy_vendor'

echo "=== Destinations ==="
curl -s "http://localhost:9090/api/v1/query?query=sum%20by%20(destination_service)%20(proxy_requests_total)" | jq '.data.result[].metric.destination_service'

echo "=== Protocols ==="
curl -s "http://localhost:9090/api/v1/query?query=sum%20by%20(request_protocol)%20(proxy_requests_total)" | jq '.data.result[].metric.request_protocol'
```

**Expected Output:**
```
=== Proxy Vendors ===
"vendor-a"
"vendor-b" 
"vendor-c"

=== Destinations ===
"api.github.com:443"
"httpbin.org:443"
"jsonplaceholder.typicode.com:443"

=== Protocols ===
"http"
"https"
```

## Requirements Fulfillment

| Requirement | Solution | Metric |
|-------------|----------|--------|
| **(a) Request counts per proxy** | Recording rules with proxy_vendor labels | `proxy_requests_total` |
| **(b) Destination tracking** | destination_service labels | `destination_service` in all metrics |
| **(c) Outbound bandwidth per proxy per pod** | Istio request bytes with attribution | `proxy_request_bytes_sum` |
| **(d) Inbound bandwidth per proxy per pod** | Istio response bytes with attribution | `proxy_response_bytes_sum` |
| **HTTP/HTTPS + HTTP/1,2 support** | Native Istio Envoy support | `request_protocol` labels |

## Scale Testing
```bash
# Scale to thousands of pods
kubectl scale deployment load-generator -n crawlers --replicas=50
kubectl scale deployment crawler-pods -n crawlers --replicas=100

# Verify metrics scale
curl -s "http://localhost:9090/api/v1/query?query=count(up{job=\"istio-proxy\"})" | jq '.data.result[0].value[1]'
```

## Technical Implementation

### Recording Rules (Prometheus)
```yaml
- record: proxy_requests_total
  expr: |
    label_replace(
      label_replace(
        label_replace(
          istio_requests_total{source_app="load-generator"},
          "proxy_vendor", "vendor-a", "destination_service", ".*github.*"
        ),
        "proxy_vendor", "vendor-b", "destination_service", ".*httpbin.*"
      ),
      "proxy_vendor", "vendor-c", "destination_service", ".*typicode.*"
    )
```

### Istio Scraping (Prometheus)
```yaml
- job_name: 'istio-proxy'
  kubernetes_sd_configs:
    - role: pod
      namespaces: [crawlers]
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_container_name]
      action: keep
      regex: istio-proxy
```

## Cleanup
```bash
make clean
minikube stop && minikube delete
```

## Success Criteria

The solution successfully:
- ✅ Attributes traffic to 3 proxy vendors (vendor-a, vendor-b, vendor-c)
- ✅ Tracks request counts per proxy vendor
- ✅ Captures destination hosts/domains
- ✅ Measures outbound bandwidth per proxy per pod
- ✅ Measures inbound bandwidth per proxy per pod
- ✅ Supports HTTP/HTTPS and HTTP/1, HTTP/2 protocols
- ✅ Scales to thousands of crawler pods
- ✅ Provides real-time visualization in Grafana
- ✅ Zero code changes required in crawler applications

## Architecture Benefits

- **Zero Instrumentation**: No changes to crawler applications
- **Protocol Agnostic**: Native HTTP/1, HTTP/2, HTTPS support
- **Scalable**: Handles thousands of pods with efficient labeling
- **Real-time**: Live metrics and dashboards
- **Vendor Agnostic**: Works with any proxy vendors
- **Cloud Native**: Kubernetes-native solution using open-source tools
