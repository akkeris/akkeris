#!/bin/sh

# TODO: Double check kubectl version! Must be over 1.14!
# TODO: Fix request for 2GB on istio-pilot
# TODO: Reduce (bare minimum) istio install
minikube start --cpus=4 --memory='4000mb' --wait=true
helm init --kube-context minikube
kubectl label namespace kube-system istio-injection=disabled
kubectl create namespace akkeris-system --context minikube
kubectl label namespace akkeris-system istio-injection=disabled --context minikube
kubectl create namespace sites-system --context minikube
kubectl label namespace sites-system istio-injection=disabled --context minikube

# kafka
./install-kafka.sh

# cert manager
./install-cert-manager.sh

# istio install
export USE_NODE_PORT_INGRESS=true
./install-istio.sh

# influx db install
./install-influxdb.sh

# nginx private ingress
./install-private-ingress.sh

# install registry
./install-registry.sh

# TODO: Install fluentd daemonset
# TODO: letsencrypt cluster issuer installation (akkeris-test.io ? with staging lets encrypt values...)
# TODO: Install akkeris ingress
# TODO: Install akkeris deployments
# TODO: .... node port ingress & dns ... ?
