
# PROVIDER ?? gcloud aws azure. export PROVIDER=gcloud
# if google: $PROJECT_ID   export PROJECT_ID=round-exchange-172320
# REGION ??   export REGION=us-west1-a
# DOMAIN ??   export DOMAIN=akkeris-test.io
# EMAIL ??    export EMAIL=...@gmail.com
# ISSUER ?? letsencrypt digicert
# CLUSTER_NAME.  export CLUSTER_NAME=kobayashi
# TODO: DNS?..

export CONTEXT_NAME="gke_${PROJECT_ID}_${REGION}_${CLUSTER_NAME}"
export GCLOUD_CLUSTER_VERSION=1.10.6-gke.2
export JENKINS_PASS=foozle

kubectl config use-context $CLUSTER_NAME

function install_letsencrypt_issuer {
  # TODO: maybe hide the bottom messages?
  helm install stable/cert-manager --kube-context $CONTEXT_NAME
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
      name: IssuerPrivateKeyName
    # Enable the HTTP-01 challenge provider
    http01: {}
EOF
  echo $issuer > /tmp/letsencrypt-issuer.yml
  kubectl create -f /tmp/letsencrypt-issuer.yml --context $CONTEXT_NAME
  # tested OK
}

function create_ssl_site {
  # $DEPLOYMENT $NAMESPACE $PORT $HOST $ISSUER
  # kubectl expose deployment $DEPLOYMENT --target-port=$PORT --type=NodePort
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
    kind: Issuer
  acme:
    config:
    - http01:
      domains:
      - $HOST
EOF
  echo $certificate > /tmp/$DEPLOYMENT-cert.yml
  kubectl create -f /tmp/$DEPLOYMENT-cert.yml --namespace=akkeris --context $CONTEXT_NAME

  read -d '' ingress <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
      ingress.kubernetes.io/ssl-redirect: "true"
  name: $DEPLOYMENT
spec:
  rules:
  - host: $HOST
    http:
      paths:
      - backend:
          serviceName: $DEPLOYMENT
          servicePort: $PORT
        path: /
  tls:
  - hosts:
    - $HOST
    secretName: $DEPLOYMENT-tls
EOF
  echo $ingress > /tmp/ingress.yml
  kubectl create -f /tmp/ingress.yml --namespace $NAMESPACE --context $CONTEXT_NAME
}

function create_google_kubernetes {
  # TODO: shouuld we add --enable-cloud-monitoring ?? exising cluster must hve at least two nodes
  # TODO: we should ensure were 1.10 at least?
  gcloud container clusters create $CLUSTER_NAME --region $REGION --num-nodes=3 --cluster-version $GCLOUD_CLUSTER_VERSION
  gcloud container clusters get-credentials $CLUSTER_NAME
  kubectl config use-context $CONTEXT_NAME
  # tested OK 
}

function install_helm() {
  kubectl config use-context $CONTEXT_NAME
  kubectl create serviceaccount --namespace kube-system tiller --context $CONTEXT_NAME
  kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller --context $CONTEXT_NAME
  helm init --service-account tiller --kube-context $CONTEXT_NAME
  kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}' --context $CONTEXT_NAME
  helm init --service-account tiller --upgrade --kube-context $CONTEXT_NAME
  # tested OK
}

function install_vault() {
  # TODO: ensure rbac is enabled with kubectl api-versions | grep rbac, should have 2 values: 
  # rbac.authorization.k8s.io/v1
  # rbac.authorization.k8s.io/v1beta1
  helm install stable/vault-operator --name vault --namespace akkeris --set etcd-operator.enabled=true --kube-context $CONTEXT_NAME
  read -d '' vaultdep <<EOF
apiVersion: "vault.security.coreos.com/v1alpha1"
kind: "VaultService"
metadata:
  name: "akkeris"
spec:
  nodes: 2
  version: "0.9.1-0"
EOF
  echo $vaultdep > /tmp/vault-cluster.yml
  # namespace must be default, no idea why...
  kubectl create -f /tmp/vault-cluster.yml --namespace default --context $CONTEXT_NAME
  sleep 1000
  # TODO: how do we wait?
  kubectl -n default get vault akkeris -o jsonpath='{.status.vaultStatus.sealed[0]}' | xargs -0 -I {} kubectl -n default port-forward {} 8200 & 
  VAULT_ADDR=https://localhost:8200 vault init -tls-skip-verify
  # TODO: capture above? prompt user about entering keys belowbelow?
  VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify
  VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify
  VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify
  killall kubectl
  # TODO: Seemingly crashes, one pod says it hasn't bene initialize? "core: security barrier not initialized"
  # TODO: Expose vault via service/ingres?  secrets.$HOST?
  # TODO: How do we test if unseal worked?
  # TODO: if we don't expose it do we allow admin to connect and tell them how?
  #       VAULT_ADDR: https://vault.akkeris:8200? (or .cluster.local) disable tls verification...

}

function install_registry() {
  helm install --name registry --namspace akkeris stable/docker-registry --kube-context $CONTEXT_NAME
  # TODO: ingress/ssl/dns/etc? http://registry-docker-registry.akkeris.svc runs on port 5000
}

function install_jenkins() {
  helm install --name jenkins --namespace akkeris stable/jenkins --set Master.AdminPassword=$JENKINS_PASS --kube-context $CONTEXT_NAME
  # TODO: loop until this doesn't error out
  export JENKINS_IP=$(kubectl get svc --namespace default exhaling-stingray-jenkins --template "{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}")
  # TODO: Add DNS entry for jenkins.$HOST?
  # TODO: let user know?
  # http://jenkins.akkeris:8080
}

function install_influxdb() {
  helm install --name metrics --namespace akkeris stable/influxdb --kube-context $CONTEXT_NAME
  # http://influxdb-influxdb.akkeris:8086
}

function install_kafka() {
  helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
  helm install --name kafkalogs --namespace akkeris incubator/kafka --kube-context $CONTEXT_NAME
  # kafkalogs-zookeeper:2181
  # kafkalogs-kafka:9092
  # TODO set number of partitions?
}

function install_akkeris_deployments() {
  # controller
  # auth
  # appkit
  # region
  # apps-watcher
  # logshuttle
  # logsession
}


function install_grafana() {

}


function install_akkeris_sites() {
  helm install --name certmanager --namespace akkeris stable/cert-manager --kube-context $CONTEXT_NAME
  DEPLOYMENT=auth NAMESPACE=akkeris PORT=5000 HOST=auth.$DOMAIN create_ssl_site
  DEPLOYMENT=appkit NAMESPACE=akkeris PORT=5000 HOST=apps.$DOMAIN create_ssl_site
}


function install_new_gcloud_and_letsencrypt() {
  gcloud config set project $PROJECT_ID
  gcloud config set compute/zone $REGION
  create_google_kubernetes
  kubectl create namespace akkeris --context $CONTEXT_NAME
  install_helm
  install_letsencrypt_issuer
  install_vault
  install_registry
  install_jenkins
  install_influxdb
  install_kafka
  install_akkeris_deployments
  install_akkeris_sites
  install_grafana
}

