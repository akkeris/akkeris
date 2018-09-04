#!/bin/bash

# export PROVIDER=gcloud
# export EMAIL=...
# export PROJECT_ID=round-exchange-172320
# export CLUSTER_NAME=kobayashi
# export ISSUER=letsencrypt
# export DOMAIN=akkeris-test.io
# export REGION=us-west1
# export ZONE="$REGION-a"

# TODO: Provision a new DNS name?..
# TODO: Install optional LDAP?..

export PYTHONIOENCODING=utf8

if [ "$PROVIDER" = "" ]; then 
  echo "The PROVIDER variable must be set to what you'd like to name the provider."
  exit 1
fi
if [ "$CLUSTER_NAME" = "" ]; then 
  echo "The CLUSTER_NAME variable must be set to what you'd like to name the cluster."
  exit 1
fi
if [ "$DOMAIN" = "" ]; then 
  echo "The DOMAIN variable must be set to the domain to use, it must be available in the provider to the cluster."
  exit 1
fi
if [ "$REGION" = "" ]; then 
  echo "The REGION variable must be set to your providers region."
  exit 1
fi
if [ "$EMAIL" = "" ]; then
  echo "The EMAIL variable must be set to the account on your provider"
  exit 1
fi
if [ "$JENKINS_PASS" = "" ]; then
  LC_CTYPE=C tr -d -c '[:alnum:]' </dev/urandom | head -c 8
  export JENKINS_PASS=$(LC_CTYPE=C tr -d -c '[:alnum:]' </dev/urandom | head -c 15)
fi
if [ "$PROVIDER" = "gcloud" ]; then
  if [ "$PROJECT_ID" == "" ]; then
    echo "The PROJECT_ID variable must be set to the project on your gcloud, see below:"
    echo 
    gcloud projects list
    exit 1
  fi

  if [ "$GCS_BUCKET_NAME" == "" ]; then
    export GCS_BUCKET_NAME="${PROJECT_ID}-vault-storage"
  fi
  if [ "$ZONE" == "" ]; then
    export ZONE="${REGION}-a"
  fi
  if [ "$GCLOUD_CLUSTER_VERSION" == "" ]; then
    export GCLOUD_CLUSTER_VERSION=1.10.6-gke.2
  fi

  export CONTEXT_NAME="gke_${PROJECT_ID}_${ZONE}_${CLUSTER_NAME}"
fi

function wait_for_result {
  echo -n $message
  while : ; do
    RES=`sh -c "$command"`
    [[ $RES == "" ]] || break
    sleep 1
    echo -n .
  done
  echo
}

function wait_for_eq {
  echo -n $message
  while : ; do
    RES=`sh -c "$command"`
    [[ $RES == "$result" ]] || break
    sleep 1
    echo -n .
  done
  echo
}


function wait_for_neq {
  echo -n $message
  while : ; do
    RES=`sh -c "$command"`
    [[ $RES != "$result" ]] || break
    sleep 1
    echo -n .
  done
  echo
}

function get_pod_name {
  export POD_NAME=$(kubectl get pods --namespace $NAMESPACE -l "app=$DEPLOYMENT" --context $CONTEXT_NAME -o jsonpath="{.items[0].metadata.name}")
}

function install_gcloud_letsencrypt_issuer {
  echo -n "Creating gcloud service account for letsencrypt... "
  # TODO: figure out how to do this without using roles/owner
  gcloud iam service-accounts create letsencrypt --display-name=letsencrypt >> install.log 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:letsencrypt@$PROJECT_ID.iam.gserviceaccount.com --role roles/owner >> install.log 2>&1
  gcloud iam service-accounts add-iam-policy-binding letsencrypt@$PROJECT_ID.iam.gserviceaccount.com --member="user:$EMAIL" --role='roles/owner' >> install.log 2>&1
  rm /tmp/letsencrypt-service.json >> install.log 2>&1
  gcloud iam service-accounts keys create /tmp/letsencrypt-service.json --iam-account letsencrypt@$PROJECT_ID.iam.gserviceaccount.com >> install.log 2>&1

  export SERVICE_ACCOUNT_DATA=`cat /tmp/letsencrypt-service.json | base64`
  read -d '' secret <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: clouddns-svc-acct-secret
  namespace: akkeris
type: Opaque
data:
  service-account.json: $SERVICE_ACCOUNT_DATA
EOF
  echo "$secret" > /tmp/letsencrypt-secret.yml
  kubectl create -f /tmp/letsencrypt-secret.yml -n akkeris --context $CONTEXT_NAME >> install.log 2>&1
  echo "✔"

  # TODO: Install ClusterIssuer not Issuer? (https://cert-manager.readthedocs.io/en/latest/reference/clusterissuers.html)
  echo -n "Installing letsencrypt issuer on gcloud... "
  helm install stable/cert-manager --namespace=akkeris --kube-context $CONTEXT_NAME >> install.log 2>&1

  export ISSUER_URL="https://acme-v02.api.letsencrypt.org/directory"
  if [ "$TEST_MODE" != "" ]; then
    export ISSUER_URL="https://acme-staging-v02.api.letsencrypt.org/directory"
  fi 

  read -d '' issuer <<EOF
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    # The ACME server URL
    server: $ISSUER_URL
    # Email address used for ACME registration
    email: "$EMAIL"
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod-private-key
    dns01:
      providers:
        - name: gcloud
          clouddns:
            project: $PROJECT_ID
            serviceAccountSecretRef:
              name: clouddns-svc-acct-secret
              key: service-account.json
EOF
  echo "$issuer" > /tmp/letsencrypt-issuer.yml
  kubectl create -f /tmp/letsencrypt-issuer.yml -n akkeris --context $CONTEXT_NAME >> install.log 2>&1
  echo "✔"
}

function install_aws_letsencrypt_issuer {
  # TODO: maybe hide the bottom messages?
  # TODO: Install ClusterIssuer not Issuer? (https://cert-manager.readthedocs.io/en/latest/reference/clusterissuers.html)
  helm install stable/cert-manager --kube-context $CONTEXT_NAME >> install.log 2>&1
  read -d '' issuer <<EOF
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: "$EMAIL"
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod-private-key
    dns01:
      providers:
        - name: aws
          route53:
            region: $ZONE

            # optional if ambient credentials are available; see ambient credentials documentation
            accessKeyID: $ACCESS_KEY_ID
            secretAccessKeySecretRef:
              name: route53-svc-acct-secret
              key: secret-access-key
EOF
  echo "$issuer" > /tmp/letsencrypt-issuer.yml
  kubectl create -f /tmp/letsencrypt-issuer.yml --context $CONTEXT_NAME >> install.log 2>&1
}

function create_gcloud_ssl_site {
  # params: $DEPLOYMENT $NAMESPACE $PORT $HOST $ISSUER
  read -d '' certificate <<EOF
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: $HOST
spec:
  secretName: $DEPLOYMENT-tls
  commonName: $HOST
  dnsNames:
  - $HOST
  issuerRef:
    name: $ISSUER
    kind: ClusterIssuer
  acme:
    config:
    - dns01:
        provider: gcloud
      domains:
      - $HOST
EOF
  echo "$certificate" > /tmp/$DEPLOYMENT-cert.yml
  kubectl create -f /tmp/$DEPLOYMENT-cert.yml -n $NAMESPACE --context $CONTEXT_NAME >> install.log 2>&1

  result="CertIssued" command="kubectl get certificate $HOST -n akkeris -o jsonpath='{.status.conditions[0].reason}' --context $CONTEXT_NAME" message="Waiting for certificate ($HOST) to be issued (this could take 5 minutes)" wait_for_neq 

  # TODO: need to add the annotation to the service:
  #   cloud.google.com/load-balancer-type: "Internal"
  # TODO: how do we deal with systems/deployments that already have a service created? or load balancer?
  # TODO: detect if a load balancer, dns entry matching or anythign else is present.
  kubectl expose service $DEPLOYMENT --type=LoadBalancer -n $NAMESPACE --name=$DEPLOYMENT-lb  --context $CONTEXT_NAME >> install.log 2>&1
  
  export ESCAPED_HOST="$DEPLOYMENT-$NAMESPACE-ingress"

  gcloud compute addresses create $ESCAPED_HOST --global >> install.log 2>&1

  # annotations are google cloud only
  read -d '' ingress <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
      kubernetes.io/ingress.allow-http: "false"
      kubernetes.io/ingress.global-static-ip-name: "$ESCAPED_HOST"
  name: $DEPLOYMENT
spec:
  rules:
  - host: $HOST
    http:
      paths:
      - backend:
          serviceName: $DEPLOYMENT-lb
          servicePort: $PORT
        path: /*
  tls:
  - hosts:
    - $HOST
    secretName: $DEPLOYMENT-tls
EOF
  echo "$ingress" > /tmp/ingress.yml
  kubectl create -f /tmp/ingress.yml --namespace $NAMESPACE --context $CONTEXT_NAME >> install.log 2>&1

  message="Waiting for ingress to be created" command="kubectl get ingress $DEPLOYMENT -n akkeris -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --context $CONTEXT_NAME" wait_for_result

  export IP_ADDRESS=`kubectl get ingress $DEPLOYMENT -n akkeris -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --context $CONTEXT_NAME`
  rm -rf /tmp/dns-update.yml >> install.log 2>&1
  gcloud dns record-sets transaction start --zone public --transaction-file=/tmp/dns-update.yml >> install.log 2>&1
  gcloud dns record-sets transaction add --name $HOST. --type A --ttl 3600 --zone public "$IP_ADDRESS" --transaction-file=/tmp/dns-update.yml >> install.log 2>&1
  gcloud dns record-sets transaction execute --zone public --transaction-file=/tmp/dns-update.yml >> install.log 2>&1
  rm -rf /tmp/dns-update.yml >> install.log 2>&1
}

function create_google_kubernetes {
  echo -n "Installing Kubernetes (this may take 10 minutes)... "
  gcloud container clusters create $CLUSTER_NAME --region $ZONE --num-nodes=3 --cluster-version $GCLOUD_CLUSTER_VERSION >> install.log 2>&1
  gcloud container clusters get-credentials $CLUSTER_NAME >> install.log 2>&1
  kubectl config use-context $CONTEXT_NAME >> install.log 2>&1
  echo "✔"
}

function install_helm {
  sleep 5
  echo -n "Installing Helm "
  kubectl config use-context $CONTEXT_NAME  >> install.log 2>&1
  kubectl create serviceaccount --namespace kube-system tiller --context $CONTEXT_NAME >> install.log 2>&1
  kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller --context $CONTEXT_NAME >> install.log 2>&1
  helm init --service-account tiller --kube-context $CONTEXT_NAME >> install.log 2>&1
  kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}' --context $CONTEXT_NAME >> install.log 2>&1
  helm init --service-account tiller --upgrade --kube-context $CONTEXT_NAME  >> install.log 2>&1
  sleep 30
  echo "✔"
}

function sanity_checks {
  if ! [ -x "$(command -v kubectl)" ]; then 
    echo "kubectl is required to use this"
    exit 1
  fi
  if [ "$PROVIDER" = "gcloud" ]; then
    if ! [ -x "$(command -v gcloud)" ]; then 
      echo "gcloud is required to use this"
      exit 1
    fi
    export ACCOUNT=`gcloud auth list --filter=status:ACTIVE --format="value(account)"`
    if [ "$ACCOUNT" = "" ]; then
      echo "gcloud must be logged in to use this"
      exit 1
    fi
  fi
  if ! [ -x "$(command -v curl)" ]; then 
    echo "curl is required to use this"
    exit 1
  fi
  if ! [ -x "$(command -v python3)" ]; then 
    echo "python3 is required to use this"
    exit 1
  fi
  if ! [ -x "$(command -v helm)" ]; then 
    echo "helm is required to use this"
    exit 1
  fi
  if ! [ -x "$(command -v cut)" ]; then 
    echo "cut is required to use this"
    exit 1
  fi
  if ! [ -x "$(command -v cat)" ]; then 
    echo "cat is required to use this"
    exit 1
  fi
  if ! [ -x "$(command -v tr)" ]; then 
    echo "tr is required to use this"
    exit 1
  fi
  if ! [ -x "$(command -v grep)" ]; then 
    echo "grep is required to use this"
    exit 1
  fi
  if ! [ -x "$(command -v wc)" ]; then 
    echo "wc is required to use this"
    exit 1
  fi
  if ! [ -x "$(command -v tr)" ]; then 
    echo "tr is required to use this"
    exit 1
  fi
  # TODO: existing cluster use should have 1.10.6 (-gke.2) at least? 
  kubectl config use-context $CONTEXT_NAME  >> install.log 2>&1
  RBAC=`kubectl api-versions --context $CONTEXT_NAME | grep rbacd | wc -l | tr -d '[:space:]'`
  if [ "$RBAC" == "0" ]; then
    echo "The kubernetes cluster $CONTEXT_NAME does not have role based access control (RBAC) enabled/installed.  Enable it and try again."
    exit 1
  fi
}

function install_gcloud_vault {
  sleep 5
  echo -n "Installing Vault "
  helm install stable/vault-operator --name vault --namespace akkeris --set etcd-operator.enabled=true --kube-context $CONTEXT_NAME >> install.log 2>&1
  echo "✔"

  echo -n "Waiting for vault to be created "
  read -d '' vaultdep <<EOF
apiVersion: "vault.security.coreos.com/v1alpha1"
kind: "VaultService"
metadata:
  name: "vault"
spec:
  nodes: 1
  version: "0.9.1-0"
EOF
  echo "$vaultdep" > /tmp/vault-cluster.yml
  # namespace must be the same as the helm install stable/vault-operator otherwise it fails.
  kubectl create -f /tmp/vault-cluster.yml --namespace akkeris --context $CONTEXT_NAME  >> install.log 2>&1
  echo "✔"

  command="kubectl -n akkeris get vault vault -o jsonpath='{.status.vaultStatus.sealed[0]}' --context $CONTEXT_NAME" message="Waiting for vault to turn on (this could take 5 minutes)" wait_for_result
  kubectl -n akkeris get vault vault -o jsonpath='{.status.vaultStatus.sealed[0]}' --context $CONTEXT_NAME | xargs -0 -I {} kubectl -n akkeris --context $CONTEXT_NAME port-forward {} 8200 >> install.log 2>&1 & 
  
  echo -n "Initializing Vault..."
  sleep 10
  # keys, recovery_keys, root_token
  curl -k -s https://localhost:8200/v1/sys/init -X PUT -d '{"secret_shares":3, "secret_threshold":2}' -H 'Accept: application/json' -H 'Content-Type: application/json' > vault.json
  # TODO, support/switch on python2? python -c "import sys, json; print json.load(sys.stdin)['name']"
  export VAULT_KEY_1=`cat vault.json | python3 -c "import sys, json; print(json.load(sys.stdin)['keys'][0])"`
  export VAULT_KEY_2=`cat vault.json | python3 -c "import sys, json; print(json.load(sys.stdin)['keys'][1])"`
  export VAULT_KEY_3=`cat vault.json | python3 -c "import sys, json; print(json.load(sys.stdin)['keys'][2])"`
  export VAULT_ROOT_TOKEN=`cat vault.json | python3 -c "import sys, json; print(json.load(sys.stdin)['root_token'])"`
  echo "✔"

  echo -n "Unsealing Vault..."
  curl -k -s https://localhost:8200/v1/sys/unseal -X PUT -d '{"reset":true}' -H 'Accept: application/json' >> install.log 2>&1
  curl -k -s https://localhost:8200/v1/sys/unseal -X PUT -d "{\"key\":\"$VAULT_KEY_1\"}" -H 'Accept: application/json' -H 'Content-Type: application/json' >> install.log 2>&1
  curl -k -s https://localhost:8200/v1/sys/unseal -X PUT -d "{\"key\":\"$VAULT_KEY_2\"}" -H 'Accept: application/json' -H 'Content-Type: application/json' >> install.log 2>&1
  curl -k -s https://localhost:8200/v1/sys/unseal -X PUT -d "{\"key\":\"$VAULT_KEY_3\"}" -H 'Accept: application/json' -H 'Content-Type: application/json' >> install.log 2>&1

  killall kubectl >> install.log 2>&1

  echo "✔"
  echo
  echo "*** IMPORTANT: Keep these keys in a safe place (they're also in vault.log) ***"
  echo
  echo " Vault Unseal Key 1: $VAULT_KEY_1"
  echo " Vault Unseal Key 2: $VAULT_KEY_2"
  echo " Vault Unseal Key 3: $VAULT_KEY_3"
  echo
  echo " Vault Root Key: $VAULT_ROOT_TOKEN"
  echo 
  echo " All of this and the recovery keys were written to vault.json, you can just save this file."
  echo
  # TODO: setup external ingress
  # Cluster Url: http://vault.akkeris:8200 External Url: https://vault.$DOMAIN
}

function install_registry {
  echo -n "Installing Docker Registry "
  helm install --name registry --namespace akkeris stable/docker-registry --kube-context $CONTEXT_NAME  >> install.log 2>&1
  echo "✔"
  # Cluster Url: http://registry-docker-registry.akkeris:5000
}

function install_jenkins {
  echo -n "Installing Jenkins "
  helm install --name jenkins --namespace akkeris stable/jenkins --set Master.AdminPassword=$JENKINS_PASS --kube-context $CONTEXT_NAME  >> install.log 2>&1
  echo "✔"
  echo "*** IMPORTANT: Jenkins master login is 'admin' and password is '$JENKINS_PASS' store these in a safe place ***"
  # TODO: how do we install plugins (dsl pipeline docker, etc)?
  # TODO: how do we set the jenkins url so it sees it in a reverse proxy?
  # TODO: loop until its up, setup standard tls ingress
  # Cluster Url: http://jenkins.akkeris:8080  External Url: https://builds.$CLUSTER.$DOMAIN
}

function install_influxdb {
  echo -n "Installing InfluxDb "
  helm install --name metrics --namespace akkeris stable/influxdb --kube-context $CONTEXT_NAME >> install.log 2>&1
  echo "✔"
  # Cluster Url http://metrics-influxdb.akkeris:8086  External Url https://metrics.$CLUSTER.$DOMAIN
  # TODO: create a database within influx for app metrics?x
}

function install_kafka {
  echo -n "Installing Kafka "
  helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator >> install.log
  helm install --name kafkalogs --namespace akkeris incubator/kafka --kube-context $CONTEXT_NAME >> install.log 2>&1
  echo "✔"
  # Cluster Hosts: kafkalogs-zookeeper.akkeris:2181 kafkalogs-kafka.akkeris:9092
  # TODO: fluentd setup to push logs?
}

function install_gcloud_akkeris_deployments {
  echo -n "Installing Akkeris Brokers "
  # TODO: ... brokers ... and preprovisioners
  echo "✔"
  echo -n "Installing Akkeris "
  # TODO: region-api
  # TODO: apps-watcher
  # TODO: logshuttle  -> needs postgres, thus postgres broker akkeris/logshuttle:release-4
  # TODO: logsession  -> needs postgres, thus postgres broker akkeris/logshuttle:release-4
  # TODO: auth
  # TODO: controller
  # TODO: appkit (appsapi)
  # TODO: akkeris-ui (akkerisui)
  # TODO: scanners
  echo "✔"
}

function init_gcloud {
  gcloud services enable cloudapis.googleapis.com cloudkms.googleapis.com container.googleapis.com containerregistry.googleapis.com iam.googleapis.com --project ${PROJECT_ID}
}

function install_grafana {
  echo -n "Installing Monitoring and Dashboards "
  # TODO: Install grafana, and dashboard templates.
  # TODO: Ingress: https://membanks.$DOMAIN
  echo "✔"
}

function install_gcloud_akkeris_sites {
  DEPLOYMENT=jenkins NAMESPACE=akkeris PORT=8080 HOST=builds.$DOMAIN ISSUER=letsencrypt create_gcloud_ssl_site
  # DEPLOYMENT=vault NAMESPACE=akkeris PORT=5000 HOST=vault.$DOMAIN ISSUER=letsencrypt create_gcloud_ssl_site
  # DEPLOYMENT=registry-docker-registry NAMESPACE=akkeris PORT=5000 HOST=registry.$DOMAIN ISSUER=letsencrypt create_gcloud_ssl_site
  # DEPLOYMENT=auth NAMESPACE=akkeris PORT=???? HOST=auth.$DOMAIN create_gcloud_ssl_site
  # DEPLOYMENT=appsapi NAMESPACE=akkeris PORT=???? HOST=apps.$DOMAIN create_gcloud_ssl_site
  # DEPLOYMENT=akkerisui NAMESPACE=akkeris PORT=???? HOST=akkeris.$DOMAIN create_gcloud_ssl_site
}

function install_new_gcloud_and_letsencrypt {
  gcloud config set project $PROJECT_ID  >> install.log 2>&1
  gcloud config set compute/zone $ZONE >> install.log 2>&1
  create_google_kubernetes
  kubectl create namespace akkeris --context $CONTEXT_NAME >> install.log 2>&1
  install_helm
  install_gcloud_letsencrypt_issuer
  install_gcloud_vault
  install_registry
  install_jenkins
  install_influxdb
  install_kafka
  install_gcloud_akkeris_deployments
  install_gcloud_akkeris_sites
  install_grafana
}

echo "Starting" > install.log
install_new_gcloud_and_letsencrypt
