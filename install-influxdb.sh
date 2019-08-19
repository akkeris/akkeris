#!/bin/sh

helm install stable/influxdb --name metrics --namespace akkeris-system -f ./helm/influxdb-values.yaml --wait --timeout 600
