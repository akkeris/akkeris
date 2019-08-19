#!/bin/sh
kubectl create namespace akkeris-system
kubectl label namespace akkeris-system istio-injection=disabled
kubectl create namespace sites-system 
kubectl label namespace kube-system istio-injection=disabled
# Note: cert manager must be up and running before this can run.

if [ "$KAFKA_BROKERS" == "" ]; then
	export LOGGING_SETTINGS="logging.brokers=\"$KAFKA_BROKERS\""
fi
if [ "$KAFKA_ZOOKEEPER" == "" ]; then
	export LOGGING_SETTINGS="logging.zookeeper=\"$KAFKA_ZOOKEEPER\""
fi

if [ "$LOGGING_SETTINGS" == "" ]; then
	export LOGGING_SETTINGS="logging.zookeeper=\"kafkalogs-zookeeper.akkeris-system\""
fi

if [ "$KUBERNETES_API_URL" == "" ]; then 
	export KUBERNETES_API_URL="kubernetes.default"
fi

if [ "$REGION_API_URL" == "" ]; then
	export REGION_API_URL="http://region-api.akkeris-system"
fi

if [ "$DOMAIN" == "" ]; then
	echo "The environment variable DOMAIN was not found"
	exit 1
fi

if [ "$CLUSTER_ISSUER" == "" ]; then
	echo "The environment variable CLUSTER_ISSUER was not found"
	exit 1
fi

if [ "$KUBERNETES_TOKEN_VAULT_PATH" == "" ]; then
	echo "The environment variable KUBERNETES_TOKEN_VAULT_PATH was not found"
	exit 1
fi

if [ "$REGION_API_SECRET_VAULT_PATH" == "" ]; then
	echo "The environment variable REGION_API_SECRET_VAULT_PATH was not found"
	exit 1
fi

if [ "$NAME" == "" ]; then
	echo "The environment variable NAME was not found"
	exit 1
fi

helm install ./helm/akkeris-ingress-chart/ --name akkeris-ingress --namespace istio-system \
	--set="$LOGGING_SETTINGS" \
	--set=domain="$DOMAIN" \
	--set=clusterissuer="$CLUSTER_ISSUER" \
	--set=name="$NAME" \
	--set=kubernetesapiurl="$KUBERNETES_API_URL" \
	--set=kubernetestokenvaultpath="$KUBERNETES_TOKEN_VAULT_PATH" \
	--set=regionapisecretvaultpath="$REGION_API_SECRET_VAULT_PATH" \
	--set=regionapiurl="$REGION_API_URL" \
	--wait --timeout 600
