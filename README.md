OCR Application/Environment Setup, Deployment Guide Doc

 Local Setup and Testing

Install python and required dependencies 
	
sudo apt update
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update
sudo apt install python3.12 python3.12-venv python3.12-dev -y
python3.12 --version
sudo apt update
sudo apt install tesseract-ocr -y
tesseract --version
curl -sSL https://install.python-poetry.org | python3 -
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
poetry --version
poetry env use python3.12



Try to install poetry with the command below and get an error as below. 


Then I created a sample readme file and retry.
echo "# OCR Model Project" > README.md
poetry install
Then I faced another issue as below.



Then I run with --no-root param and it works.
poetry install --no-root.



Then I started the KServe Model Service.
poetry run python model.py



Then I open another terminal and start Gateway Service as well.
poetry run python api-gateway.py















Then i Validate both services are working as expected.











































But when I was trying to send an image I got this error. 
To fix this we need to modify the model.py file to accept a list, not string.








Then it works.









Containerization

Create 2 docker files for both Model and Gateway and save them Inside the Docker repo.
And create 4 simple shell scripts to build the images , push the images to docker hub, run the containers locally and test them using curl locally. Those all shell scripts are included in scripts repo.
We need to change the below line because we deploy both dockers in the same network called ocr-network. 




Docker Best Practises:
python:3.12-slim: Official Python image, minimal size (~45MB vs 380MB+ for full).
Multi-stage builds: Separate build and runtime environments.
Non-root user: All containers run as appuser (not root).
Minimal system packages: Only install necessary dependencies.
Health checks: Built-in monitoring for container health.
Minimal runtime dependencies: Only runtime packages in the final stage.


I created a few shell scripts to build docker images, push them to docker hub, run the images. 
And Gave execute permissions to them.
chmod +x *
Execute the start.sh script to start both docker containers.
./start.sh 





 Infrastructure Setup

Remove old Docker installations.
sudo apt remove -y docker docker-engine docker.io containerd runc

Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

Configure Docker for current user
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker
newgrp docker

Verify Docker installation
docker --version 
docker run hello-world

Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
	
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

Verify kubectl installation
kubectl version --client

Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

 Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
minikube version
minikube start --driver=docker
kubectl get nodes
Install minikube addones 
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard

Create Required Namespaces
kubectl create namespace argocd
kubectl create namespace monitoring
kubectl create namespace ocr-app

Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
Verify ArgoCD installation
kubectl get pods -n argocd


Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

Port Forward to access ArgoCD UI
nohup kubectl port-forward --address 0.0.0.0 -n argocd service/argocd-server 8080:443 > port-forward.log 2>&1 &

Install Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=2Gi \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=1Gi \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=1Gi

Verify Prometheus installation
kubectl --namespace monitoring get pods -l "release=monitoring"


Get Grafana admin password
kubectl --namespace monitoring get secrets monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d; echo


Port Forward to access grafana UI
nohup bash -c 'export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=monitoring" -o jsonpath="{.items[0].metadata.name}"); kubectl --namespace monitoring port-forward $POD_NAME 3000:3000' > grafana-portforward.log 2>&1 &

Deploy OCR Applications with Helm
I created 2 separated helm charts for both ocr model and ocr gateway.


Here are the followed steps.
helm create ocr-model
helm create ocr-gateway


Then after remove unwanted files and modify templates, values and chart.yml files.
Validate Helm charts
helm lint ocr-model
helm lint ocr-gateway
helm template ocr-model ocr-model
helm template ocr-gateway ocr-gateway


Deploy applications
helm install ocr-model ./ocr-model --namespace ocr-app
helm install ocr-gateway ./ocr-gateway --namespace ocr-app


Verify deployments
kubectl get pods -n ocr-app
kubectl get services -n ocr-app


Forward traffic for external access
kubectl port-forward --address 0.0.0.0 -n ocr-app service/ocr-model 8080:8080 > /dev/null 2>&1 &
kubectl port-forward --address 0.0.0.0 -n ocr-app service/ocr-gateway 8001:8001 > /dev/null 2>&1 &

Check all pods across namespaces
kubectl get pods --all-namespaces
kubectl get services --all-namespaces
kubectl get pods -n argocd
kubectl get pods -n monitoring
kubectl get pods -n ocr-app







Kubernetes Deployment

	Modify Templates folder with chart.yaml and values.yaml
	


GitOps with ArgoCD

Now we have all scripts, helm files, and k8s deployment files in the local folder.
Now create an argocd folder inside k8s and create below files for applicationset, appproject, ocr-gateway-app and ocr-model-app yaml files.
Then apply yaml files.
kubectl apply -f appproject.yaml
kubectl apply -f applicationset.yaml
Then inside argocd UI we can see both model and gateway application.
If we run 
kubectl get pod -n orc-app
We can see 2 pods.

Monitoring Setup
Inside the k8s folder we need to create a folder called monitoring and create servicemonitor.
Then apply the created servicemonitor yaml file.
Then push the changes to github.
Then login to Grafana and create below Dashboards using below queries.
Service Status 
up{job="ocr-model"}
Memory Usage
process_resident_memory_bytes{job="ocr-model"} / 1024 / 1024
CPU Usage
rate(process_cpu_seconds_total{job="ocr-model"}[5m]) * 100
Request Rate
rate(python_gc_collections_total{job="ocr-model",generation="0"}[5m])
Python GC Activity
python_gc_objects_collected_total{job="ocr-model"}
Model Inference Latency Histogram
python_gc_collections_total{job="ocr-model"}
Request Success Rate / Error Rate
up{job="ocr-model"} * 100

 

















Simple Architecture Diagram (URL)







Now we need to forward the traffic to the outside world.


kubectl port-forward --address 0.0.0.0 -n ocr-app service/ocr-model 8080:8080 > /dev/null 2>&1 &
kubectl port-forward --address 0.0.0.0 -n ocr-app service/ocr-gateway 8001:8001 > /dev/null 2>&1 &










