# Data Model & Schema

## Overview

This document describes the data model and schema for proxy usage metrics collected by the observability solution.

## Metrics Schema

### Core Metrics

#### 1. Request Count Metrics
```
istio_requests_total{
  source_app="crawler",
  source_version="v1",
  source_workload="crawler-pods",
  source_namespace="crawlers",
  destination_service_name="external",
  destination_service_namespace="unknown",
  proxy_vendor="vendor-a|vendor-b|vendor-c",
  proxy_ip="10.1.1.1",
  destination_host="httpbin.org",
  request_protocol="http|https",
  response_code="200"
}
```

#### 2. Bandwidth Metrics (Outbound)
```
istio_request_bytes_sum{
  source_app="crawler",
  source_workload="crawler-pods",
  source_namespace="crawlers",
  proxy_vendor="vendor-a|vendor-b|vendor-c",
  proxy_ip="10.1.1.1",
  destination_host="httpbin.org"
}
```

#### 3. Bandwidth Metrics (Inbound)
```
istio_response_bytes_sum{
  source_app="crawler",
  source_workload="crawler-pods", 
  source_namespace="crawlers",
  proxy_vendor="vendor-a|vendor-b|vendor-c",
  proxy_ip="10.1.1.1",
  destination_host="httpbin.org"
}
```

#### 4. Request Duration
```
istio_request_duration_milliseconds_sum{
  source_app="crawler",
  proxy_vendor="vendor-a|vendor-b|vendor-c",
  destination_host="httpbin.org",
  request_protocol="http|https"
}
```

## Label Definitions

| Label | Description | Example Values |
|-------|-------------|----------------|
| `source_app` | Application making the request | `crawler`, `load-generator` |
| `source_workload` | Kubernetes workload name | `crawler-pods`, `load-generator` |
| `source_namespace` | Kubernetes namespace | `crawlers` |
| `proxy_vendor` | Proxy vendor identifier | `vendor-a`, `vendor-b`, `vendor-c` |
| `proxy_ip` | Actual proxy IP address | `10.1.1.1`, `10.2.1.2` |
| `destination_host` | Target hostname | `httpbin.org`, `api.github.com` |
| `destination_service_name` | Service name (if internal) | `external` for external services |
| `request_protocol` | HTTP protocol version | `http`, `https` |
| `response_code` | HTTP response status | `200`, `404`, `500` |

## Query Examples

### 1. Total Requests by Vendor
```promql
sum by (proxy_vendor) (
  rate(istio_requests_total{source_app="crawler"}[5m])
)
```

### 2. Bandwidth Usage by Vendor (Outbound)
```promql
sum by (proxy_vendor) (
  rate(istio_request_bytes_sum{source_app="crawler"}[5m])
)
```

### 3. Top Destinations
```promql
topk(10, 
  sum by (destination_host) (
    rate(istio_requests_total{source_app="crawler"}[5m])
  )
)
```

### 4. Per-Pod Bandwidth Usage
```promql
sum by (source_workload, proxy_vendor) (
  rate(istio_request_bytes_sum{source_app="crawler"}[5m]) +
  rate(istio_response_bytes_sum{source_app="crawler"}[5m])
)
```