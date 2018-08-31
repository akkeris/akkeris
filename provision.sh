#!/bin/bash

# export PROVIDER=gcloud
# export EMAIL=...
# export PROJECT_ID=round-exchange-172320
# export CLUSTER_NAME=kobayashi
# export ISSUER=letsencrypt
# export DOMAIN=akkeris-test.io
# export REGION=us-west1-a

# TODO: Provision a new DNS name?..
# TODO: Install optional LDAP?..

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
  export CONTEXT_NAME="gke_${PROJECT_ID}_${REGION}_${CLUSTER_NAME}"
  export GCLOUD_CLUSTER_VERSION=1.10.6-gke.2
fi

function wait_for_result {
  echo -n $message
  while : ; do
    RES=`$command`
    [[ $RES == "" ]] || break
    sleep 1
    echo -n .
  done
  echo
}

function wait_for_eq {
  echo -n $message
  while : ; do
    RES=`$command`
    [[ $RES == "$result" ]] || break
    sleep 1
    echo -n .
  done
  echo
}

function get_pod_name {
  export POD_NAME=$(kubectl get pods --namespace $NAMESPACE -l "app=$DEPLOYMENT" --context $CONTEXT_NAME -o jsonpath="{.items[0].metadata.name}")
}

function install_gcloud_letsencrypt_issuer {
  sleep 30
  # TODO: figure out how to do this without using roles/owner
  gcloud iam service-accounts create letsencrypt --display-name=letsencrypt
  gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:letsencrypt@$PROJECT_ID.iam.gserviceaccount.com --role roles/owner
  gcloud iam service-accounts add-iam-policy-binding letsencrypt@$PROJECT_ID.iam.gserviceaccount.com --member="user:$EMAIL" --role='roles/owner'
  rm /tmp/letsencrypt-service.json
  gcloud iam service-accounts keys create /tmp/letsencrypt-service.json --iam-account letsencrypt@$PROJECT_ID.iam.gserviceaccount.com 

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
  echo $secret > /tmp/letsencrypt-secret.yml
  kubectl create -f /tmp/letsencrypt-secret.yml -n akkeris --context $CONTEXT_NAME 

  # TODO: Install ClusterIssuer not Issuer? (https://cert-manager.readthedocs.io/en/latest/reference/clusterissuers.html)
  helm install stable/cert-manager --namespace=akkeris --kube-context $CONTEXT_NAME 
  read -d '' issuer <<EOF
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
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
        - name: gcloud
          clouddns:
            project: $PROJECT_ID
            serviceAccountSecretRef:
              name: clouddns-svc-acct-secret
              key: service-account.json
EOF
  echo $issuer > /tmp/letsencrypt-issuer.yml
  kubectl create -f /tmp/letsencrypt-issuer.yml -n akkeris --context $CONTEXT_NAME >> install.log
}

function install_aws_letsencrypt_issuer {
  # TODO: maybe hide the bottom messages?
  # TODO: Install ClusterIssuer not Issuer? (https://cert-manager.readthedocs.io/en/latest/reference/clusterissuers.html)
  helm install stable/cert-manager --kube-context $CONTEXT_NAME >> install.log
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
            region: $REGION

            # optional if ambient credentials are available; see ambient credentials documentation
            accessKeyID: $ACCESS_KEY_ID
            secretAccessKeySecretRef:
              name: route53-svc-acct-secret
              key: secret-access-key
EOF
  echo $issuer > /tmp/letsencrypt-issuer.yml
  kubectl create -f /tmp/letsencrypt-issuer.yml --context $CONTEXT_NAME >> install.log
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
  acme:
    config:
    - dns01:
        provider: gcloud
      domains:
      - $HOST
EOF
  echo $certificate > /tmp/$DEPLOYMENT-cert.yml
  kubectl create -f /tmp/$DEPLOYMENT-cert.yml -n $NAMESPACE --context $CONTEXT_NAME  >> install.log
  echo -n "Waiting for certificate ($HOST) to be issued (this could take 5 minutes)"
  while : ; do
    RES=`kubectl get certificate $HOST -n akkeris -o jsonpath='{.status.conditions[0].reason}' --context $CONTEXT_NAME`
    [[ $RES != "CertIssued" ]] || break
    sleep 1
    echo -n .
  done
  echo

  # TODO: need to add the annotation to the service:
  #   cloud.google.com/load-balancer-type: "Internal"
  # TODO: how do we deal with systems/deployments that already have a service created? or load balancer?

  kubectl expose service $DEPLOYMENT --type=LoadBalancer -n $NAMESPACE --name=$DEPLOYMENT-lb  --context $CONTEXT_NAME >> install.log
  
  
  export ESCAPED_HOST="$DEPLOYMENT-$NAMESPACE-ingress"

  gcloud compute addresses create $ESCAPED_HOST --global >> install.log

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
  echo $ingress > /tmp/ingress.yml
  kubectl create -f /tmp/ingress.yml --namespace $NAMESPACE --context $CONTEXT_NAME >> install.log

  echo -n "Waiting for ingress to be created"
  while : ; do
    RES=`kubectl get ingress $DEPLOYMENT -n akkeris -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --context $CONTEXT_NAME`
    [[ $RES == "" ]] || break
    sleep 1
    echo -n .
  done
  echo

  export IP_ADDRESS=`kubectl get ingress $DEPLOYMENT -n akkeris -o jsonpath='{.status.loadBalancer.ingress[0].ip}'  --context $CONTEXT_NAME`
  rm -rf /tmp/dns-update.yml
  gcloud dns record-sets transaction start --zone public --transaction-file=/tmp/dns-update.yml >> install.log
  gcloud dns record-sets transaction add --name $HOST. --type A --ttl 3600 --zone public "$IP_ADDRESS" --transaction-file=/tmp/dns-update.yml >> install.log
  gcloud dns record-sets transaction execute --zone public --transaction-file=/tmp/dns-update.yml >> install.log
  rm -rf /tmp/dns-update.yml
  # tested EH, OK.
}

function create_google_kubernetes {
  gcloud container clusters create $CLUSTER_NAME --region $REGION --num-nodes=3 --cluster-version $GCLOUD_CLUSTER_VERSION
  gcloud container clusters get-credentials $CLUSTER_NAME >> install.log
  kubectl config use-context $CONTEXT_NAME >> install.log
}

function install_helm() {
  kubectl config use-context $CONTEXT_NAME >> install.log
  kubectl create serviceaccount --namespace kube-system tiller --context $CONTEXT_NAME >> install.log
  kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller --context $CONTEXT_NAME >> install.log
  helm init --service-account tiller --kube-context $CONTEXT_NAME >> install.log
  kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}' --context $CONTEXT_NAME >> install.log
  helm init --service-account tiller --upgrade --kube-context $CONTEXT_NAME >> install.log
}

function sanity_checks() {
  # check kubectl is installed
  # check gcloud is installed and is logged in
  # see if grep exists
  # see if wc exists
  # see if tr exists
  # see if helm exists
  # see if read exists
  # see if cat exists
  # see if cut exists
  # see if vault exist, and its using v0.10.4+
  # TODO: existing cluster use should have 1.10.6 (-gke.2) at least? 
  kubectl config use-context $CONTEXT_NAME
  RBAC=`kubectl api-versions --context $CONTEXT_NAME | grep rbacd | wc -l | tr -d '[:space:]'`
  if [ "$RBAC" == "0" ]; then
    echo "The kubernetes cluster $CONTEXT_NAME does not have role based access control (RBAC) enabled/installed.  Enable it and try again."
    exit 1
  fi
}

function install_gcloud_vault() {
  sleep 30
  echo -n "Installing Vault "
  helm install stable/vault-operator --name vault --namespace akkeris --set etcd-operator.enabled=true --kube-context $CONTEXT_NAME >> install.log
  echo "\u2714"

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
  echo $vaultdep > /tmp/vault-cluster.yml
  # namespace must be the same as the helm install stable/vault-operator otherwise it fails.
  kubectl create -f /tmp/vault-cluster.yml --namespace akkeris --context $CONTEXT_NAME >> install.log
  
  while : ; do
    RES=`kubectl -n akkeris get vault vault -o jsonpath='{.status.vaultStatus.sealed[0]}' --context $CONTEXT_NAME` 
    [[ $RES == "" ]] || break
    sleep 1
    echo -n .
  done
  echo "\u2714"
  kubectl -n akkeris get vault vault -o jsonpath='{.status.vaultStatus.sealed[0]}' --context $CONTEXT_NAME | xargs -0 -I {} kubectl -n akkeris --context $CONTEXT_NAME port-forward {} 8200 & 
  
  echo -n "Initializing Vault..."
  VAULT_ADDR=https://localhost:8200 vault init -tls-skip-verify > vault.log
  echo "\u2714"

  export VAULT_KEYS=`cat vault.log | grep 'Unseal Key' | cut -d ':' -f 2 | tr -d ' '`
  export count=0
  while read -r line; do
    export count=$((count+1))
    declare VAULT_KEY_$count=$line
  done <<< "$VAULT_KEYS"

  export VAULT_ROOT_TOKEN=`cat vault.log | grep 'Initial Root Token:' | cut -d ':' -f 2 | tr -d ' '`
  
  echo -n "Unsealing Vault..."

  echo $VAULT_KEY_1 | VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify >> vault.log
  echo $VAULT_KEY_2 | VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify >> vault.log
  echo $VAULT_KEY_3 | VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify >> vault.log

  echo "\u2714"
  echo
  echo "*** IMPORTANT: Keep these keys in a safe place (they're also in vault.log) ***"
  echo
  echo " Vault Unseal Key 1: $VAULT_KEY_1"
  echo " Vault Unseal Key 2: $VAULT_KEY_2"
  echo " Vault Unseal Key 3: $VAULT_KEY_3"
  echo " Vault Unseal Key 4: $VAULT_KEY_4"
  echo " Vault Unseal Key 5: $VAULT_KEY_5"
  echo
  echo " Vault Root Key: $VAULT_ROOT_TOKEN"
  echo

  killall kubectl >> install.log
  # TODO: Generate a certificate for vault.$DOMAIN
  # TODO: Once generated, rewrite the tokens to a config val vault handles.
  # TODO: Expose akkeris -n akkeris service via TCP load balancer (port 8200)
  # TODO: Rewrite the TLS config on vault.
  # Cluster Url: https://vault.akkeris:8200 (VAULT_SERVICE_HOST/VAULT_SERVICE_PORT) - must skip verify to reach this.
  # External Url: https://vault.$DOMAIN
}

function install_registry() {
  echo -n "Installing Docker Registry "
  helm install --name registry --namespace akkeris stable/docker-registry --kube-context $CONTEXT_NAME >> install.log
  echo "\u2714"
  # Cluster Url: http://registry-docker-registry.akkeris:5000
}

function install_jenkins() {
  echo -n "Installing Jenkins "
  helm install --name jenkins --namespace akkeris stable/jenkins --set Master.AdminPassword=$JENKINS_PASS --kube-context $CONTEXT_NAME >> install.log
  echo "\u2714"
  echo "*** IMPORTANT: Jenkins master login is 'admin' and password is '$JENKINS_PASS' store these in a safe place ***"
  # TODO: how do we install plugins (dsl pipeline docker, etc)?
  # TODO: how do we set the jenkins url so it sees it in a reverse proxy?
  # TODO: loop until its up, setup standard tls ingress
  # Cluster Url: http://jenkins.akkeris:8080
  # External Url: https://builds.$CLUSTER.$DOMAIN
}

function install_influxdb() {
  echo -n "Installing InfluxDb "
  helm install --name metrics --namespace akkeris stable/influxdb --kube-context $CONTEXT_NAME >> install.log
  echo "\u2714"
  # Cluster Url http://metrics-influxdb.akkeris:8086
  # External Url https://metrics.$CLUSTER.$DOMAIN
  # TODO: create a database within influx for app metrics?x
}

function install_kafka() {
  echo -n "Installing Kafka "
  helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator >> install.log
  helm install --name kafkalogs --namespace akkeris incubator/kafka --kube-context $CONTEXT_NAME >> install.log
  echo "\u2714"
  # Cluster Hosts: kafkalogs-zookeeper.akkeris:2181 kafkalogs-kafka.akkeris:9092
  # TODO: fluentd setup to push logs?
}

function install_gcloud_akkeris_deployments() {
  echo -n "Installing Akkeris Brokers "
  # TODO: ... brokers ... and preprovisioners
  echo "\u2714"
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
  echo "\u2714"
}


function install_grafana() {
  echo -n "Installing Monitoring and Dashboards "
  # TODO: Install grafana, and dashboard templates.
  # TODO: Ingress: https://membanks.$DOMAIN
  echo "\u2714"
}


function install_gcloud_akkeris_sites() {
  DEPLOYMENT=jenkins NAMESPACE=akkeris PORT=8080 HOST=builds.$DOMAIN ISSUER=letsencrypt create_gcloud_ssl_site
  DEPLOYMENT=registry-docker-registry NAMESPACE=akkeris PORT=8080 HOST=registry.$DOMAIN ISSUER=letsencrypt create_gcloud_ssl_site
  # DEPLOYMENT=auth NAMESPACE=akkeris PORT=5000 HOST=auth.$DOMAIN create_gcloud_ssl_site
  # DEPLOYMENT=appsapi NAMESPACE=akkeris PORT=5000 HOST=apps.$DOMAIN create_gcloud_ssl_site
  # DEPLOYMENT=akkerisui NAMESPACE=akkeris PORT=5000 HOST=akkeris.$DOMAIN create_gcloud_ssl_site
}

function install_new_gcloud_and_letsencrypt() {
  gcloud config set project $PROJECT_ID
  gcloud config set compute/zone $REGION
  create_google_kubernetes
  kubectl create namespace akkeris --context $CONTEXT_NAME
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


# sanity_checks
install_new_gcloud_and_letsencrypt
