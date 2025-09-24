.PHONY: help build deploy validate clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build Docker images
	@echo "Building Docker images..."
	@chmod +x scripts/build-images.sh
	@./scripts/build-images.sh

deploy: ## Deploy the complete solution
	@echo "Deploying proxy monitoring solution..."
	@chmod +x scripts/deploy.sh
	@./scripts/deploy.sh

validate: ## Validate the deployment
	@echo "Validating deployment..."
	@chmod +x scripts/validate.sh
	@./scripts/validate.sh

clean: ## Clean up the deployment
	@echo "Cleaning up..."
	@helm uninstall crawler-simulation -n crawlers || true
	@helm uninstall monitoring-stack -n monitoring || true
	@kubectl delete namespace crawlers monitoring || true

setup-cluster: ## Setup local cluster (minikube)
	@echo "Setting up minikube cluster..."
	@minikube start
	@echo "Installing Istio..."
	@curl -L https://istio.io/downloadIstio | sh -
	@cd istio-* && export PATH=$$PWD/bin:$$PATH && istioctl install --set values.defaultRevision=default -y
	@kubectl label namespace default istio-injection=enabled

port-forward: ## Setup port forwarding for dashboards
	@echo "Setting up port forwarding..."
	@echo "Grafana will be available at http://localhost:3000"
	@echo "Prometheus will be available at http://localhost:9090"
	@kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80 &
	@kubectl port-forward -n monitoring svc/monitoring-stack-prometheus-server 9090:80 &
	@echo "Port forwarding started in background"

stop-port-forward: ## Stop port forwarding
	@pkill -f "kubectl port-forward" || true

all: build deploy validate ## Build, deploy and validate everything

quick-start: setup-cluster build deploy port-forward ## Complete setup from scratch

deploy-fast: build deploy port-forward ## Deploy without cluster setup (assumes cluster ready)

troubleshoot: ## Diagnose deployment issues
	@chmod +x scripts/troubleshoot.sh
	@./scripts/troubleshoot.sh