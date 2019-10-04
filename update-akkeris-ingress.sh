#!/bin/sh
kubectl label namespace akkeris-system istio-injections=disabled
kubectl label namespace kube-system istio-injection=disabled
helm upgrade akkeris-ingress ./helm/akkeris-ingress-chart/ --reuse-values
kubectl delete fluentd/handler -n istio-system > /dev/null
kubectl delete accesslog/logentry -n istio-system > /dev/null
