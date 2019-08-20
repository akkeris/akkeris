#!/bin/sh
echo "Installing Kafka"
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm install --name kafkalogs incubator/kafka --namespace akkeris-system -f ./helm/kafka-values.yaml --wait --timeout 600
echo "Installing Kafka... Done"