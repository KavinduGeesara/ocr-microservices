#!/bin/bash

set -e

echo "Starting infrastructure setup..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git vim unzip

echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
rm get-docker.sh

echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "Installing Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

echo "Please logout and login again for Docker group changes to take effect."
echo "Then run: minikube start --driver=docker --memory=12288 --cpus=6 --disk-size=40g --kubernetes-version=v1.28.0"
echo "After that, run the second part of this setup..."

# Save the rest to a second script
cat > setup-k8s.sh << 'EOF'
#!/bin/bash

set -e

minikube addons enable ingress
minikube addons enable metrics-server

echo "Creating namespaces..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ocr-app --dry-run=client -o yaml | kubectl apply -f -

echo "Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "Adding helm repos..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "Installing monitoring stack..."
helm install monitoring prometheus-community/kube-prometheus-stack \
 --namespace monitoring \
 --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=5Gi \
 --set prometheus.prometheusSpec.resources.requests.memory=2Gi \
 --set prometheus.prometheusSpec.resources.limits.memory=4Gi \
 --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=2Gi \
 --set grafana.persistence.enabled=true \
 --set grafana.persistence.size=3Gi \
 --wait

echo "Setup complete!"
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
kubectl port-forward --address 0.0.0.0 -n argocd svc/argocd-server 8443:443 > /dev/null 2>&1 &
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-grafana 3000:80 > /dev/null 2>&1 &
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 > /dev/null 2>&1 &

echo "Services accessible at:"
echo "ArgoCD: https://$(hostname -I | awk '{print $1}'):8443"
echo "Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
EOF

chmod +x setup-k8s.sh
echo "Created setup-k8s.sh - run this after logout/login and minikube start"
