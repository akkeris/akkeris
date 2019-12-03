#!/bin/sh

echo "Installing Akkeris Runtime..."

kubectl create namespace akkeris-system
kubectl label namespace akkeris-system istio-injection=disabled

# TODO: install logshuttle/logession

# TODO: install buildshuttle

# TODO: install downpage

# TODO: install database broker

# TODO: install apps watcher

# TODO: install 

# TODO: install region api

# TODO: install controller api

# TODO: install akkeris api

# TODO: Ingress?...


helm install ./helm/akkeris-runtime-chart/ --name akkeris-runtime --namespace akkeris-system --wait --timeout 600

echo "Installing Akkeris Ingress... Done"