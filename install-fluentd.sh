#!/bin/sh

echo "Installing Fluentd..."
kubectl apply -n kube-system -f logshuttle-fluentd/manifest.yml
echo "Installing Fluentd... Done"