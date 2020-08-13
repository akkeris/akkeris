#!/bin/sh

echo "Installing Akkeris Ingress..."

if [ "$DOMAIN" == "" ]; then
	echo "The environment variable DOMAIN was not found"
	exit 1
fi

if [ "$NAME" == "" ]; then
	export NAME="minikube"
fi

if [ "$LOGGING_SETTINGS" == "" ]; then
	export LOGGING_SETTINGS="logging.zookeeper=\"kafkalogs-zookeeper.akkeris-system:2181\""
fi

if [ "$KUBERNETES_API_URL" == "" ]; then 
	export KUBERNETES_API_URL="kubernetes.default"
fi

if [ "$REGION_API_URL" == "" ]; then
	export REGION_API_URL="http://region-api.akkeris-system"
fi

if [ "$CLUSTER_ISSUER" == "" ]; then
	export CLUSTER_ISSUER="aws"
fi

helm install ./helm/akkeris-ingress-chart/ --name akkeris-ingress --namespace istio-system \
	--set="$LOGGING_SETTINGS" \
	--set=domain="$DOMAIN" \
	--set=clusterissuer="$CLUSTER_ISSUER" \
	--set=name="$NAME" \
	--set=kubernetesapiurl="$KUBERNETES_API_URL" \
	--set=kubernetestoken="" \
	--set=regionapiusername="" \
	--set=regionapipassword="" \
	--set=regionapiurl="$REGION_API_URL" \
	--wait --timeout 600

echo "Installing Akkeris Ingress... Done"