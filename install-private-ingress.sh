#!/bin/sh

echo "Installing Private Ingress... "

if [ "$PRIVATE_INGRESS_USE_AWS_NLB" == "true" ]; then 
	helm install --name nginx-ingress-i --namespace nginx-ingress-i stable/nginx-ingress \
		--set controller.stats.enabled=true \
		--set controller.metrics.enabled=true \
		--set controller.ingressClass=nginx-internal \
		--set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
		--set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"=true \
		--set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-internal"="0.0.0.0/0" \
		--wait --timeout 800
else
	helm install --name nginx-ingress-i --namespace nginx-ingress-i stable/nginx-ingress \
		--set controller.stats.enabled=true \
		--set controller.metrics.enabled=true \
		--set controller.ingressClass=nginx-internal \
		--wait --timeout 800
if

echo "Installing Private Ingress... Done"