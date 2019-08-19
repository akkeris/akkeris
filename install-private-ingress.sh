#!/bin/sh
helm install --name nginx-ingress-i --namespace nginx-ingress-i stable/nginx-ingress \
	--set controller.stats.enabled=true \
	--set controller.metrics.enabled=true \
	--set controller.ingressClass=nginx-internal \
	--set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
	--set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"=true \
	--set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-internal"="0.0.0.0/0" \
	--wait --timeout 600
