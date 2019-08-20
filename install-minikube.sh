#!/bin/sh

command -v minikube >/dev/null 2>&1 || { echo >&2 "minikube is required for this to run"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo >&2 "kubectl is required for this to run"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo >&2 "helm is required for this to run"; exit 1; }
minikube addons enable metrics-server
minikube start --cpus=4 --memory='4000mb' --wait=true
helm init --kube-context minikube --wait
kubectl label namespace kube-system istio-injection=disabled
kubectl create namespace akkeris-system --context minikube
kubectl label namespace akkeris-system istio-injection=disabled --context minikube
kubectl create namespace sites-system --context minikube
kubectl label namespace sites-system istio-injection=disabled --context minikube

./install-kafka.sh

./install-cert-manager.sh

export USE_NODE_PORT_INGRESS=true
export ISTIO_MINIMAL=true
./install-istio.sh

./install-influxdb.sh

./install-private-ingress.sh

./install-registry.sh

./install-vault-dev-mode.sh