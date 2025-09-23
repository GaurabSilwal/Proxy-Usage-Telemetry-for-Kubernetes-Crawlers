# Kubernetes Proxy Usage Observability Solution

## Architecture Overview

This solution provides comprehensive observability for outbound proxy usage from crawler pods in a Kubernetes cluster. It tracks requests, bandwidth, and destinations across multiple proxy vendors.

### Components

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Crawler Pods  │───▶│  Istio Sidecar   │───▶│  Proxy Vendors  │
│   (crawlers ns) │    │  (Envoy Proxy)   │    │  (vendor-a/b/c) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │
         │                       ▼
         │              ┌──────────────────┐
         │              │   Prometheus     │
         │              │   (Metrics)      │
         │              └──────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌──────────────────┐
│   Load Gen      │    │     Grafana      │
│   (Synthetic)   │    │  (Dashboards)    │
└─────────────────┘    └──────────────────┘
```

### Key Features

- **Traffic Attribution**: Automatically attributes traffic to correct proxy vendor
- **Multi-Protocol Support**: HTTP/1, HTTP/2, HTTPS
- **Comprehensive Metrics**: Request counts, bandwidth (in/out), destinations
- **Real-time Monitoring**: Live dashboards and alerting
- **Scalable**: Handles thousands of crawler pods

### Metrics Collected

| Metric | Description | Labels |
|--------|-------------|--------|
| `proxy_requests_total` | Total requests per proxy | `pod`, `vendor`, `destination_host`, `proxy_ip` |
| `proxy_bytes_sent_total` | Outbound bytes per proxy | `pod`, `vendor`, `proxy_ip` |
| `proxy_bytes_received_total` | Inbound bytes per proxy | `pod`, `vendor`, `proxy_ip` |
| `proxy_request_duration_seconds` | Request latency | `pod`, `vendor`, `destination_host` |

## Quick Start

### Prerequisites

- Docker
- kubectl
- Helm 3.x
- minikube or k3s cluster

### 1. Start Local Cluster

```bash
# Using minikube
minikube start --memory=8192 --cpus=4 --kubernetes-version=v1.28.0

# Or using k3s
curl -sfL https://get.k3s.io | sh -
```

### 2. Install Istio

```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
istioctl install --set values.defaultRevision=default -y
kubectl label namespace default istio-injection=enabled
```

### 3. Deploy the Solution

```bash
# Clone and navigate to project
cd analytics-eks-monitoring

# Install monitoring stack
helm install monitoring ./helm/monitoring-stack -n monitoring --create-namespace

# Install crawler simulation
helm install crawlers ./helm/crawler-simulation -n crawlers --create-namespace

# Enable Istio injection for crawlers namespace
kubectl label namespace crawlers istio-injection=enabled
```

### 4. Access Dashboards

```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Access at http://localhost:3000
# Default credentials: admin/admin
```

### 5. Generate Load

```bash
# Scale up load generators
kubectl scale deployment load-generator -n crawlers --replicas=10

# Monitor metrics
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Access at http://localhost:9090
```

## Validation

### Check Metrics Collection

```bash
# Verify Istio metrics
kubectl exec -n istio-system deployment/istiod -- pilot-discovery proxy-config bootstrap <pod-name>

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Validate custom metrics
curl http://localhost:9090/api/v1/query?query=proxy_requests_total
```

### Dashboard Verification

1. Open Grafana at http://localhost:3000
2. Navigate to "Proxy Usage Dashboard"
3. Verify metrics for:
   - Request counts by vendor
   - Bandwidth usage trends
   - Top destinations
   - Pod-level breakdowns

## Architecture Decisions

### Why Istio Service Mesh?

- **Automatic Traffic Interception**: No code changes required
- **Rich Telemetry**: Built-in metrics for HTTP/HTTPS traffic
- **Protocol Support**: Native HTTP/1, HTTP/2, HTTPS handling
- **Scalability**: Proven at enterprise scale

### Why Prometheus + Grafana?

- **Industry Standard**: De facto monitoring stack for Kubernetes
- **Rich Query Language**: PromQL for complex metric analysis
- **Alerting**: Built-in alerting capabilities
- **Ecosystem**: Large community and plugin ecosystem

### Trade-offs

| Aspect | Pros | Cons |
|--------|------|------|
| Istio | Rich telemetry, no app changes | Resource overhead, complexity |
| Sidecar Pattern | Per-pod metrics, isolation | Memory/CPU per pod |
| Pull-based Metrics | Reliable, scalable | Slight delay in data |

## Troubleshooting

### Common Issues

1. **Missing Metrics**: Ensure Istio injection is enabled
2. **High Resource Usage**: Tune Istio proxy resources
3. **Dashboard Empty**: Check Prometheus scraping configuration

### Debug Commands

```bash
# Check Istio proxy status
istioctl proxy-status

# Verify sidecar injection
kubectl get pods -n crawlers -o jsonpath='{.items[*].spec.containers[*].name}'

# Check Envoy configuration
istioctl proxy-config cluster <pod-name> -n crawlers
```

## Production Considerations

- **Resource Limits**: Set appropriate CPU/memory limits for sidecars
- **Retention**: Configure Prometheus retention based on storage capacity
- **High Availability**: Deploy Prometheus and Grafana in HA mode
- **Security**: Enable mTLS and RBAC for production workloads
- **Monitoring**: Monitor the monitoring stack itself

## License

MIT License - See LICENSE file for details