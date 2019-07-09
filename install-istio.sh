#!/bin/sh
if [ "$ISTIO_VERSION" == "" ]; then
	export ISTIO_VERSION="1.2.2"
fi

kubectl label namespace kube-system istio-injection=disabled

helm repo add istio.io "https://storage.googleapis.com/istio-release/releases/$ISTIO_VERSION/charts/"
helm repo update

if [ "$USE_NODE_PORT_INGRESS" == "" ]; then
	helm install istio.io/istio \
		--name istio \
		-f "./helm/istio-$ISTIO_VERSION-values.yaml" \
		--version "$ISTIO_VERSION" \
		--namespace istio-system
else
	echo "Installing node port ingress"
	helm install istio.io/istio \
		-f "./helm/istio-$ISTIO_VERSION-values.yaml" \
		--version "$ISTIO_VERSION" \
		--namespace istio-system \
		--name istio \
  		--set=gateways.sites-public-ingressgateway.type=NodePort \
  		--set=gateways.sites-private-ingressgateway.type=NodePort \
  		--set=gateways.apps-public-ingressgateway.type=NodePort \
  		--set=gateways.apps-private-ingressgateway.type=NodePort
fi