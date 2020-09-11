#!/bin/sh
echo "Installing Kafka"
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator

if [ "$KAFKA_MINIMAL" == "true" ]; then
	helm install --name kafkalogs incubator/kafka --namespace akkeris-system \
		-f ./helm/kafka-values.yaml \
		--set replicas=1 --set kafkaHeapOptions="-Xmx256M -Xms256M" \
		--wait --timeout 600
else
	helm install --name kafkalogs incubator/kafka --set=external.domain=$CLUSTER.$DOMAIN --namespace akkeris-system -f ./helm/kafka-values.yaml --wait --timeout 600
fi

echo "Installing Kafka... Done"