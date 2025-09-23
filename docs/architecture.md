# Architecture Document

## System Overview

The proxy usage observability solution provides comprehensive monitoring for thousands of crawler pods using different proxy vendors in a Kubernetes environment.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌──────────────────┐                   │
│  │   Crawler Pods  │───▶│  Istio Sidecar   │                   │
│  │   (crawlers ns) │    │  (Envoy Proxy)   │                   │
│  └─────────────────┘    └──────────────────┘                   │
│           │                       │                             │
│           │              ┌────────▼────────┐                   │
│           │              │   Telemetry     │                   │
│           │              │   Processing    │                   │
│           │              └────────┬────────┘                   │
│           │                       │                             │
│  ┌────────▼────────┐    ┌────────▼────────┐                   │
│  │  Load Generator │    │   Prometheus    │                   │
│  │   (Synthetic)   │    │   (Metrics)     │                   │
│  └─────────────────┘    └────────┬────────┘                   │
│                                   │                             │
│                          ┌────────▼────────┐                   │
│                          │     Grafana     │                   │
│                          │  (Dashboards)   │                   │
│                          └─────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
                                   │
                          ┌────────▼────────┐
                          │  Proxy Vendors  │
                          │  (vendor-a/b/c) │
                          └─────────────────┘
```

## Component Details

### 1. Istio Service Mesh
- **Purpose**: Traffic interception and telemetry generation
- **Components**: 
  - Envoy sidecars for each crawler pod
  - Istiod control plane
  - Custom telemetry configuration
- **Benefits**: 
  - Zero-code instrumentation
  - Rich HTTP/HTTPS metrics
  - Protocol-agnostic monitoring

### 2. Telemetry Processing
- **Envoy Lua Filter**: Adds proxy vendor attribution
- **Custom Labels**: Enriches metrics with proxy information
- **Protocol Support**: HTTP/1, HTTP/2, HTTPS

### 3. Metrics Collection (Prometheus)
- **Scraping**: Pulls metrics from Envoy sidecars
- **Storage**: Time-series database for metrics
- **Retention**: Configurable (7 days default)

### 4. Visualization (Grafana)
- **Dashboards**: Pre-built proxy usage dashboards
- **Alerting**: Configurable alerts for anomalies
- **Data Source**: Connected to Prometheus

### 5. Load Generation
- **Synthetic Traffic**: Simulates real crawler behavior
- **Multi-Vendor**: Uses all configured proxy vendors
- **Configurable**: Adjustable request rates and patterns

## Data Flow

```
1. Crawler Pod Request
   ↓
2. Istio Sidecar Intercepts
   ↓
3. Envoy Filter Adds Labels
   ↓
4. Request Forwarded to Proxy
   ↓
5. Metrics Generated
   ↓
6. Prometheus Scrapes Metrics
   ↓
7. Grafana Visualizes Data
```

## Key Design Decisions

### Why Istio Service Mesh?

**Pros:**
- Automatic traffic interception
- Rich telemetry without code changes
- Industry-standard solution
- Supports HTTP/1, HTTP/2, HTTPS

**Cons:**
- Resource overhead (CPU/Memory)
- Additional complexity
- Learning curve

**Alternative Considered:** Application-level instrumentation
- Rejected due to need for code changes in crawler applications

### Why Prometheus + Grafana?

**Pros:**
- De facto standard for Kubernetes monitoring
- Rich query language (PromQL)
- Large ecosystem and community
- Built-in alerting

**Cons:**
- Pull-based model has slight latency
- Storage limitations for long-term retention

**Alternative Considered:** ELK Stack
- Rejected due to complexity and resource requirements for this use case

### Proxy Vendor Attribution Strategy

**Approach:** IP-based mapping using Envoy Lua filter
- `10.1.x.x` → vendor-a
- `10.2.x.x` → vendor-b  
- `10.3.x.x` → vendor-c

**Pros:**
- Simple and reliable
- No external dependencies
- Fast processing

**Cons:**
- Requires IP range coordination
- Manual configuration updates

**Alternative Considered:** DNS-based attribution
- Rejected due to potential DNS resolution delays

## Scalability Considerations

### Horizontal Scaling
- **Crawler Pods**: Can scale to thousands of pods
- **Prometheus**: Supports federation for large deployments
- **Grafana**: Can run in HA mode

### Resource Requirements (per 1000 pods)
- **Istio Sidecars**: ~200MB memory, 0.1 CPU per pod
- **Prometheus**: ~4GB memory, 2 CPU cores
- **Grafana**: ~512MB memory, 0.5 CPU cores

### Performance Optimizations
- Metric sampling for high-volume scenarios
- Recording rules for frequently queried metrics
- Efficient label cardinality management

## Security Considerations

### Network Security
- mTLS between services (Istio default)
- Network policies for traffic isolation
- Secure proxy configurations

### Access Control
- RBAC for Kubernetes resources
- Grafana authentication and authorization
- Prometheus access controls

### Data Privacy
- No sensitive data in metrics labels
- Configurable metric retention
- Secure storage for long-term archives

## Monitoring the Monitoring Stack

### Health Checks
- Prometheus target health monitoring
- Grafana datasource connectivity
- Istio control plane status

### Key Metrics to Monitor
- Metric ingestion rate
- Query performance
- Storage utilization
- Sidecar resource usage

### Alerting Rules
```yaml
- alert: PrometheusDown
  expr: up{job="prometheus"} == 0
  for: 1m
  
- alert: HighMetricIngestionRate  
  expr: rate(prometheus_tsdb_samples_appended_total[5m]) > 10000
  for: 5m
```

## Deployment Architecture

### Namespaces
- `monitoring`: Prometheus, Grafana
- `crawlers`: Crawler pods, load generators
- `istio-system`: Istio control plane

### Resource Allocation
```yaml
monitoring:
  requests: 6GB memory, 3 CPU cores
  limits: 8GB memory, 4 CPU cores

crawlers:  
  requests: 100MB memory, 0.1 CPU per pod
  limits: 256MB memory, 0.5 CPU per pod
```

## Disaster Recovery

### Backup Strategy
- Prometheus data: Persistent volumes with snapshots
- Grafana dashboards: Version controlled in Git
- Configuration: Stored in Helm charts

### Recovery Procedures
1. Restore persistent volumes
2. Redeploy Helm charts
3. Verify metric collection
4. Validate dashboards

## Future Enhancements

### Short Term (1-3 months)
- Custom alerting rules
- Additional dashboard panels
- Performance optimizations

### Medium Term (3-6 months)
- Long-term storage integration
- Advanced analytics
- Machine learning anomaly detection

### Long Term (6+ months)
- Multi-cluster support
- Cost optimization features
- Integration with external systems