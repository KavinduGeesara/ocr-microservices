#!/bin/bash

# Infrastructure setup script for DevOps assignment
# Installs docker, kubectl, helm, minikube and sets up cluster with argocd, prometheus and grafana

echo "Starting infrastructure setup..."

# Update system
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git vim unzip

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
rm get-docker.sh

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Minikube
echo "Installing Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# Apply docker group changes
newgrp docker << END

# Check if minikube is running and stop it
minikube status && minikube stop || true

# Start minikube with more resources
echo "Starting minikube cluster..."
minikube start --driver=docker --memory=12288 --cpus=6 --disk-size=40g --kubernetes-version=v1.28.0

# Enable addons
minikube addons enable ingress
minikube addons enable metrics-server

echo "Cluster started. Creating namespaces..."

# Create namespaces
kubectl create namespace argocd
kubectl create namespace monitoring
kubectl create namespace ocr-app

echo "Installing ArgoCD..."

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for argocd server
echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "Adding helm repos..."

# Add helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "Installing monitoring stack..."

# Install prometheus and grafana
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=5Gi \
  --set prometheus.prometheusSpec.resources.requests.memory=2Gi \
  --set prometheus.prometheusSpec.resources.limits.memory=4Gi \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=2Gi \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=3Gi

# Wait for grafana
echo "Waiting for Grafana to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/monitoring-grafana -n monitoring

echo "Setup complete!"

# Get passwords
echo ""
echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo ""
echo "Grafana admin password:"
kubectl get secret --namespace monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
echo ""

echo ""
echo "Starting port forwarding..."

# Start port forwards
kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8443:443 &
kubectl port-forward --address 0.0.0.0 svc/monitoring-grafana -n monitoring 3000:80 &
kubectl port-forward --address 0.0.0.0 svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090 &

echo "Port forwarding started. Services accessible at:"
echo "ArgoCD: https://YOUR-VM-IP:8443"
echo "Grafana: http://YOUR-VM-IP:3000"
echo "Prometheus: http://YOUR-VM-IP:9090"

END