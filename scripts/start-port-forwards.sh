#!/bin/bash

echo "Starting port forwards..."

pkill -f "port-forward" || true

kubectl port-forward --address 0.0.0.0 -n argocd svc/argocd-server 8443:443 > /dev/null 2>&1 &
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-grafana 3000:80 > /dev/null 2>&1 &
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 > /dev/null 2>&1 &
kubectl port-forward --address 0.0.0.0 -n ocr-app service/ocr-model 8080:8080 > /dev/null 2>&1 &
kubectl port-forward --address 0.0.0.0 -n ocr-app service/ocr-gateway 8001:8001 > /dev/null 2>&1 &

echo "Port forwards started!"
echo "Services accessible at YOUR-PUBLIC-IP on ports: 8443, 3000, 9090, 8080, 8001"
