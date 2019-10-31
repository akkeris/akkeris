#!/bin/bash

# Set external AWS domain here
export DOMAIN=""

# Check basic requirements
command -v minikube >/dev/null 2>&1 || { echo >&2 "minikube is required for this to run"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo >&2 "kubectl is required for this to run"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo >&2 "helm is required for this to run"; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "git is required for this to run"; exit 1; }

KUBECTL_VERSION="$(kubectl version --client -o json | awk '/gitVersion/ {print$2}' | sed 's/[",v]//g')"
[[ $KUBECTL_VERSION < "1.14" ]] && { echo "kubectl version must be 1.14 or higher for this to run"; exit 1; }

# Fetch helm submodules
git submodule init
git submodule update

# Spin up minikube
minikube start --cpus=4 --memory='4000mb' --wait=true
minikube addons enable heapster
minikube addons enable metrics-server
helm init --kube-context minikube --wait

# Set up required namespaces
kubectl label namespace kube-system istio-injection=disabled
kubectl create namespace akkeris-system --context minikube
kubectl label namespace akkeris-system istio-injection=disabled --context minikube
kubectl create namespace sites-system --context minikube
kubectl label namespace sites-system istio-injection=disabled --context minikube

export KAFKA_MINIMAL=true
./install-kafka.sh

./install-cert-manager.sh

export USE_NODE_PORT_INGRESS=true
export ISTIO_MINIMAL=true
./install-istio.sh

./install-influxdb.sh

# Create private (nginx) ingress
./install-private-ingress.sh

# Install Docker registry (for build shuttle)
./install-registry.sh

# Install Vault, create vault secrets
./install-vault-dev-mode.sh

# Create service account for akkeris-system and write token (and regionapi secret) to vault
./install-svc-account.sh

# Install logshuttle-fluentd (sends logs to Kafka for logshuttle)
./install-fluentd.sh

# Install Akkeris ingress
./install-akkeris-ingress.sh

# Create a postgres database for internal systems
# 
# UNTESTED:
#
#
helm install --name akkeris-database \
	--set=postgresqlPassword=changeit \
	--set=postgresqlDatabase=akkeris \
	--set=persistance.enabled=false \
	--set=replication.slaveReplicas=0 \
	--set=replication.enabled=false \
	stable/postgresql --namespace=akkeris-system --kube-context minikube

export AKKERIS_DATABASE_URL="postgres://postgres:changeit@akkeris-database.akkeris-system:5432"
export AKKERIS_DATABASE_HOST="akkeris-database.akkeris-system"
export AKKERIS_DATABASE_USER="postgres"
export AKKERIS_DATABASE_PASS="changeit"
export AKKERIS_DATABASE_PORT="5432"
./install-akkeris-runtime.sh
