#!/bin/sh

echo "Installing InfluxDb..."
helm install stable/influxdb --name metrics --namespace akkeris-system -f ./helm/influxdb-values.yaml --wait --timeout 600
echo "Installing InfluxDb... Done"
