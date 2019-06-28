## Akkeris Ingress

Creates certificates, gateways and logging system for akkeris.  This requires:

1. Cert manager to already be installed with a cluster issuer created
2. Istio 1.1.x installed already and available (assuming in istio-system)

To upgrade

helm upgrade akkeris-ingress ./helm/akkeris-ingress-chart --version 1.1.5 --reuse-values [optionally any set overrides]

Updating istio:

 helm upgrade istio istio.io/istio --version 1.1.4 -f ./helm/istio-1.1.4-values.yaml \
 	--set=gateways.sites-public-ingressgateway.type=NodePort \
    --set=gateways.sites-private-ingressgateway.type=NodePort \
    --set=gateways.apps-public-ingressgateway.type=NodePort \
    --set=gateways.apps-private-ingressgateway.type=NodePort
