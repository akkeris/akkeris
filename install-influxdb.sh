#!/bin/sh

echo "Installing InfluxDb..."
helm install stable/influxdb --set enterprise.enabled=false --name metrics --namespace akkeris-system -f ./helm/influxdb-values.yaml --wait --timeout 600
echo "Installing InfluxDb... Done"
