echo "Creating Akkeris service account..."

VAULT_ADDR_IP=`kubectl get services -n akkeris-system vault -o jsonpath='{.spec.clusterIP}'`

# Create service account and add cluster permissions

kubectl apply -n akkeris-system -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: akkeris
EOF

kubectl create clusterrolebinding akkeris-service-account \
  --clusterrole=cluster-admin \
  --serviceaccount=akkeris-system:akkeris

echo "Creating Akkeris service account... done"

echo "Writing service account token to Vault..."

SVCACCT_TOKEN_NAME=`kubectl get serviceaccount -n akkeris-system akkeris -o jsonpath='{.secrets[*].name}'`
SVCACCT_TOKEN_SECRET=`kubectl get secret -n akkeris-system $SVCACCT_TOKEN_NAME -o jsonpath='{.data.token}' | base64 --decode`
SVCACCT_TOKEN_PATH="secret/apitoken"
VAULT_TOKEN="root"
REGIONAPI_SECRET_PATH="secret/regionapi"
REGIONAPI_USERNAME="username"
REGIONAPI_PASSWORD="password"

# Write secrets to Vault
kubectl run -n akkeris-system vault \
  --rm --attach --restart=Never --image=vault \
  --env="SVCACCT_TOKEN_SECRET=$SVCACCT_TOKEN_SECRET" \
  --env="SVCACCT_TOKEN_PATH=$SVCACCT_TOKEN_PATH" \
  --env="VAULT_TOKEN=$VAULT_TOKEN" \
  --env="REGIONAPI_SECRET_PATH=$REGIONAPI_SECRET_PATH" \
  --env="REGIONAPI_USERNAME=$REGIONAPI_USERNAME" \
  --env="REGIONAPI_PASSWORD=$REGIONAPI_PASSWORD" \
  -- /bin/sh -c \
  ' export VAULT_ADDR=http://$VAULT_SERVICE_HOST:$VAULT_SERVICE_PORT;
    vault kv put $SVCACCT_TOKEN_PATH token=$SVCACCT_TOKEN_SECRET;
    vault kv put $REGIONAPI_SECRET_PATH username=$REGIONAPI_USERNAME password=$REGIONAPI_PASSWORD;'

echo "Writing service account token to Vault... done"