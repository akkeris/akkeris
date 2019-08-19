#!/bin/sh

# TODO: use s3 if available?

helm install --name registry --namespace akkeris stable/docker-registry --wait --timeout 600