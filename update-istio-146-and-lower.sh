#!/bin/sh
if [ "$ISTIO_VERSION" == "" ]; then
	export ISTIO_VERSION="1.4.6"
fi
if [ "$ISTIO_USE_PROMETHEUS" == "" ]
then
	export ISTIO_USE_PROMETHEUS="true"
fi
export ISTIO_SUFFIX=""
if [ "$ISTIO_MINIMAL" == "true" ]
then
	export ISTIO_SUFFIX="-min"
	export ISTIO_USE_PROMETHEUS="false"
fi

kubectl label namespace kube-system istio-injection=disabled

helm repo add istio.io "https://storage.googleapis.com/istio-release/releases/$ISTIO_VERSION/charts/"
helm repo update

helm upgrade istio-init istio.io/istio-init --version "$ISTIO_VERSION" --force

echo "Waiting for istio CRD jobs to finish"
sleep 60

if [ "$USE_NODE_PORT_INGRESS" == "" ]; then
	helm upgrade istio istio.io/istio \
		-f "./helm/istio-$ISTIO_VERSION-values$ISTIO_SUFFIX.yaml" \
		--set=prometheus.enabled=$ISTIO_USE_PROMETHEUS \
		--version "$ISTIO_VERSION"
else
	echo "Upgrading node port ingress"
	helm upgrade istio istio.io/istio \
		-f "./helm/istio-$ISTIO_VERSION-values$ISTIO_SUFFIX.yaml" \
		--version "$ISTIO_VERSION" \
		--set=prometheus.enabled=$ISTIO_USE_PROMETHEUS \
		--set=gateways.sites-public-ingressgateway.type=NodePort \
		--set=gateways.sites-private-ingressgateway.type=NodePort \
		--set=gateways.apps-public-ingressgateway.type=NodePort \
		--set=gateways.apps-private-ingressgateway.type=NodePort
fi

# kubectl apply -f ./expansion-gateway.yaml -n istio-system
