#!/bin/sh
kubectl label namespace kube-system istio-injection=disabled
helm upgrade akkeris-ingress ./helm/akkeris-ingress-chart/ --reuse-values
kubectl delete fluentd/handler -n istio-system > /dev/null
kubectl delete logentry/accesslog -n istio-system > /dev/null