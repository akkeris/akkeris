#!/bin/sh
if [ "$ISTIO_VERSION" == "" ]; then
	export ISTIO_VERSION="1.6.7"
fi
if [ "$ISTIO_VERSION" != `istioctl version -s --remote=false` ]; then
	echo "Ensure your istioctl is at version $ISTIO_VERSION and try again."
	exit 1
fi

kubectl label namespace kube-system istio-injection=disabled

if [ "$USE_NODE_PORT_INGRESS" == "" ]; then
	istioctl install -f "./istioctl/istio-$ISTIO_VERSION-profile-awsnlb.yml"
else
	echo "Upgrading node port ingress"
	istioctl install -f "./istioctl/istio-$ISTIO_VERSION-profile-nodeport.yml"
fi