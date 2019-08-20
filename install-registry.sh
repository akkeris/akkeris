#!/bin/sh

echo "Installing Registry..."
helm install --name registry --namespace akkeris-system stable/docker-registry --wait --timeout 600
echo "Installing Registry... Done"