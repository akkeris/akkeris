#!/bin/bash

command -v minikube >/dev/null 2>&1 || { echo >&2 "minikube is required for this to run"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo >&2 "kubectl is required for this to run"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo >&2 "helm is required for this to run"; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "git is required for this to run"; exit 1; }
git submodule init
git submodule update
minikube start --cpus=4 --memory='4000mb' --wait=true
minikube addons enable heapster
minikube addons enable metrics-server
helm init --kube-context minikube --wait
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

./install-private-ingress.sh

./install-registry.sh

./install-vault-dev-mode.sh