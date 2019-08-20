#!/bin/sh
echo "Installing Istio"
if [ "$ISTIO_VERSION" == "" ]; then
	export ISTIO_VERSION="1.2.4"
fi

export ISTIO_SUFFIX=""
if [ "$ISTIO_MINIMAL" == "true" ]; then
	export ISTIO_SUFFIX="-min"
fi

kubectl label namespace kube-system istio-injection=disabled
kubectl label namespace nginx-ingress-i istio-injection=disabled
kubectl label namespace akkeris-system istio-injection=disabled
kubectl label namespace cert-manager istio-injection=disabled

helm repo add istio.io "https://storage.googleapis.com/istio-release/releases/$ISTIO_VERSION/charts/"
helm repo update

helm install istio.io/istio-init --version "$ISTIO_VERSION" --namespace istio-system --name istio-init --wait --timeout 600
echo "Waiting for CRDs jobs to finish..."
sleep 90

if [ "$USE_NODE_PORT_INGRESS" == "" ]; then
	helm install istio.io/istio \
		--wait --timeout 600 \
		--name istio \
		-f "./helm/istio-$ISTIO_VERSION-values$ISTIO_SUFFIX.yaml" \
		--version "$ISTIO_VERSION" \
		--namespace istio-system
else
	echo "Installing node port ingress"
	helm install istio.io/istio \
		 --wait --timeout 600 \
		-f "./helm/istio-$ISTIO_VERSION-values$ISTIO_SUFFIX.yaml" \
		--version "$ISTIO_VERSION" \
		--namespace istio-system \
		--name istio \
  		--set=gateways.sites-public-ingressgateway.type=NodePort \
  		--set=gateways.sites-private-ingressgateway.type=NodePort \
  		--set=gateways.apps-public-ingressgateway.type=NodePort \
  		--set=gateways.apps-private-ingressgateway.type=NodePort
fi
echo "Installing Istio... Done"