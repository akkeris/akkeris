#!/bin/sh
kubectl label namespace kube-system istio-injection=disabled
helm upgrade akkeris-ingress ./helm/akkeris-ingress-chart/ --reuse-values