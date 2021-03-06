#!/bin/bash

echo "*** DO NOT USE THIS IN PRODUCTIONN ***"
echo "*** FOR TESTING ONLY ***"
echo "Installing vault in dev mode... "

helm install ./helm/modules/vault-helm/ \
  --name=vault --namespace akkeris-system \
  --set='server.dev.enabled=true' \
  --set='global.image=vault:0.6.4' \
  --wait --timeout 600

kubectl logs vault-0 -n akkeris-system
echo "Installing vault in dev mode... done"

echo "Creating vault secret... "
export VAULT_ADDR_IP=`kubectl get services -n akkeris-system vault -o jsonpath='{.spec.clusterIP}'`
export VAULT_ADDR_B64=`echo -n "http://$VAULT_ADDR_IP:8200" | base64`
export VAULT_TOKEN_B64=`echo -n "root" | base64`

read -d '' secret <<EOF
apiVersion: v1
data:
  VAULT_ADDR: $VAULT_ADDR_B64
  VAULT_TOKEN: $VAULT_TOKEN_B64
kind: Secret
metadata:
  name: akkeris-system-vault
  namespace: akkeris-system
type: Opaque
EOF

echo "$secret" > /tmp/vault-minikube-secret.yaml

kubectl apply -f /tmp/vault-minikube-secret.yaml -n akkeris-system
rm /tmp/vault-minikube-secret.yaml
echo "Creating vault secret... done"