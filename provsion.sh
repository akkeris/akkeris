
# http://registry-docker-registry.akkeris:5000 - docker registry
# http://jenkins.akkeris:8080 - jenkins (admin/foozle)
# http://metrics-influxdb.akkeris:8086 - influxdb
# https://vault.akkeris:8200 - vault (TLS is not verified!)
# kafkalogs-kafka:9092 / kafkalogs-kafka.akkeris:9092 / kafkalogs-zookeeper:2181 / kafkalogs-zookeeper.akkeris:2181 - kakfa and zookeeper
# 

# PROVIDER ?? gcloud aws azure. export PROVIDER=gcloud
# if google: $PROJECT_ID   export PROJECT_ID=round-exchange-172320
# REGION ??   export REGION=us-west1-a (us-west1-a is a zone not a region, how do we differntiate?)
# DOMAIN ??   export DOMAIN=akkeris-test.io
# EMAIL ??    export EMAIL=...@gmail.com
# ISSUER ?? letsencrypt digicert
# CLUSTER_NAME.  
# TODO: DNS?..


# export PROVIDER=gcloud
# export EMAIL=...
# export PROJECT_ID=round-exchange-172320
# export CLUSTER_NAME=kobayashi
# export ISSUER=letsencrypt
# export DOMAIN=akkeris-test.io
# export REGION=us-west1-a

export CONTEXT_NAME="gke_${PROJECT_ID}_${REGION}_${CLUSTER_NAME}"
export GCLOUD_CLUSTER_VERSION=1.10.6-gke.2
export JENKINS_PASS=foozle

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
function install_gcloud_letsencrypt_issuer {
  # create service account.
  # TODO: figure otu how to do this without using roles/owner
  gcloud iam service-accounts create letsencrypt --display-name=letsencrypt
  gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:letsencrypt@$PROJECT_ID.iam.gserviceaccount.com --role roles/owner
  gcloud iam service-accounts add-iam-policy-binding letsencrypt@$PROJECT_ID.iam.gserviceaccount.com --member="user:$EMAIL" --role='roles/owner'
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
  kubectl create -f /tmp/letsencrypt-issuer.yml -n akkeris --context $CONTEXT_NAME
}

function install_aws_letsencrypt_issuer {
  # TODO: maybe hide the bottom messages?
  # TODO: Install ClusterIssuer not Issuer? (https://cert-manager.readthedocs.io/en/latest/reference/clusterissuers.html)
  helm install stable/cert-manager --kube-context $CONTEXT_NAME
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
  kubectl create -f /tmp/letsencrypt-issuer.yml --context $CONTEXT_NAME
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
  kubectl create -f /tmp/$DEPLOYMENT-cert.yml -n $NAMESPACE 
  echo -n "Waiting for certificate ($HOST) to be issued (this could take 5 minutes)"
  while : ; do
    RES=`kubectl get certificate $HOST -n akkeris -o jsonpath='{.status.conditions[0].reason}'`
    [[ $RES != "CertIssued" ]] || break
    sleep 1
    echo -n .
  done
  echo

  # TODO: need to add the annotation to the service:
  #   cloud.google.com/load-balancer-type: "Internal"
  # TODO: how do we deal with systems/deployments that already have a service created? or load balancer?

  kubectl expose service $DEPLOYMENT --type=LoadBalancer -n $NAMESPACE --name=$DEPLOYMENT-lb
  
  
  export ESCAPED_HOST="$DEPLOYMENT-$NAMESPACE-ingress"

  gcloud compute addresses create $ESCAPED_HOST --global

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
  kubectl create -f /tmp/ingress.yml --namespace $NAMESPACE --context $CONTEXT_NAME

  echo -n "Waiting for ingress to be created"
  while : ; do
    RES=`kubectl get ingress $DEPLOYMENT -n akkeris -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
    [[ $RES == "" ]] || break
    sleep 1
    echo -n .
  done
  echo

  export IP_ADDRESS=`kubectl get ingress $DEPLOYMENT -n akkeris -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
  rm -rf /tmp/dns-update.yml
  gcloud dns record-sets transaction start --zone public --transaction-file=/tmp/dns-update.yml
  gcloud dns record-sets transaction add --name $HOST. --type A --ttl 3600 --zone public "$IP_ADDRESS" --transaction-file=/tmp/dns-update.yml
  gcloud dns record-sets transaction execute --zone public --transaction-file=/tmp/dns-update.yml
  rm -rf /tmp/dns-update.yml
  # tested EH, OK.
}

function create_google_kubernetes {
  # TODO: existing should have 1.10.6 (-gke.2) at least? exising cluster must hve at least two nodes
  gcloud container clusters create $CLUSTER_NAME --region $REGION --num-nodes=3 --cluster-version $GCLOUD_CLUSTER_VERSION
  gcloud container clusters get-credentials $CLUSTER_NAME
  kubectl config use-context $CONTEXT_NAME
}

function install_helm() {
  kubectl config use-context $CONTEXT_NAME
  kubectl create serviceaccount --namespace kube-system tiller --context $CONTEXT_NAME
  kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller --context $CONTEXT_NAME
  helm init --service-account tiller --kube-context $CONTEXT_NAME
  kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}' --context $CONTEXT_NAME
  helm init --service-account tiller --upgrade --kube-context $CONTEXT_NAME
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
  kubectl config use-context $CONTEXT_NAME
  RBAC=`kubectl api-versions --context $CONTEXT_NAME | grep rbacd | wc -l | tr -d '[:space:]'`
  if [ "$RBAC" == "0" ]; then
    echo "The kubernetes cluster $CONTEXT_NAME does not have role based access control (RBAC) enabled/installed.  Enable it and try again."
    exit 1
  fi
}

function install_vault() {
  helm install stable/vault-operator --name vault --namespace akkeris --set etcd-operator.enabled=true --kube-context $CONTEXT_NAME
  read -d '' vaultdep <<EOF
apiVersion: "vault.security.coreos.com/v1alpha1"
kind: "VaultService"
metadata:
  name: "akkeris"
spec:
  nodes: 1
  version: "0.9.1-0"
EOF
  echo $vaultdep > /tmp/vault-cluster.yml
  # namespace must be the same as the helm install stable/vault-operator otherwise it fails.
  kubectl create -f /tmp/vault-cluster.yml --namespace akkeris --context $CONTEXT_NAME
  echo -n "Waiting for vault to be created "
  while : ; do
    RES=`kubectl -n akkeris get vault akkeris -o jsonpath='{.status.vaultStatus.sealed[0]}'`
    [[ $RES == "" ]] || break
    sleep 1
    echo -n .
  done
  echo "\u2714"
  kubectl -n akkeris get vault akkeris -o jsonpath='{.status.vaultStatus.sealed[0]}' | xargs -0 -I {} kubectl -n akkeris port-forward {} 8200 & 
  
  echo -n "Initializing Vault..."
  VAULT_ADDR=https://localhost:8200 vault init -tls-skip-verify > vault-init.log
  echo "\u2714"

  export VAULT_KEYS=`cat vault.log | grep 'Unseal Key' | cut -d ':' -f 2 | tr -d ' '
  count=0
  while read -r line; do
    count=$((count+1))
    declare VAULT_KEY_$count=$line
  done <<< "$VAULT_KEYS"

  export VAULT_ROOT_TOKEN=`cat vault.log | grep 'Initial Root Token:' | cut -d ':' -f 2 | tr -d ' '`
  
  echo -n "Unsealing Vault..."

  echo $VAULT_KEY_1 | VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify >> vault.log
  echo $VAULT_KEY_2 | VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify >> vault.log
  echo $VAULT_KEY_3| VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify >> vault.log

  killall kubectl

  echo "\u2714"
  echo
  echo "*** IMPORTANT: Keep these keys in a safe place (they're also in vault.log) ***"
  echo " Vault Unseal Key 1: $VAULT_KEY_1"
  echo " Vault Unseal Key 2: $VAULT_KEY_1"
  echo " Vault Unseal Key 3: $VAULT_KEY_1"
  echo " Vault Unseal Key 4: $VAULT_KEY_1"
  echo " Vault Unseal Key 5: $VAULT_KEY_1"
  echo
  echo " Vault Root Key: $VAULT_ROOT_TOKEN"
  echo
  # TODO: ingress, get a cert, set the secret value keys, specify custom tls properties in vault creation, create a tcp load balancer on static ip and let valut handle its own tls.
}

function install_registry() {
  helm install --name registry --namespace akkeris stable/docker-registry --kube-context $CONTEXT_NAME
  # http://registry-docker-registry.akkeris:5000
  # export POD_NAME=$(kubectl get pods --namespace akkeris -l "app=docker-registry,release=registry" -o jsonpath="{.items[0].metadata.name}")
  # echo "Visit http://127.0.0.1:8080 to use your application"
  # kubectl port-forward $POD_NAME 8080:5000
  #
  # TODO: ingress? registry.$DOMAIN
  # tested OK
}

function install_jenkins() {
  # TODO: how do we install plugins?
  # TODO: how do we set the jenkins url so it sees it in a reverse proxy?
  helm install --name jenkins --namespace akkeris stable/jenkins --set Master.AdminPassword=$JENKINS_PASS --kube-context $CONTEXT_NAME
  # TODO: loop until this doesn't error out
  export JENKINS_IP=$(kubectl get svc --namespace default exhaling-stingray-jenkins --template "{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}")
  # 1. Get your 'admin' user password by running:
  #  printf $(kubectl get secret --namespace akkeris jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
  # 2. Get the Jenkins URL to visit by running these commands in the same shell:
  #  NOTE: It may take a few minutes for the LoadBalancer IP to be available.
  #      You can watch the status of by running 'kubectl get svc --namespace akkeris -w jenkins'
  #  export SERVICE_IP=$(kubectl get svc --namespace akkeris jenkins --template "{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}")
  #  echo http://$SERVICE_IP:8080/login
  # http://jenkins.akkeris:8080
  # TODO: ingress? jenkins.$DOMAIN
  # TODO: install pipeline plugins, etc ?
  # tested OK
}

function install_influxdb() {
  helm install --name metrics --namespace akkeris stable/influxdb --kube-context $CONTEXT_NAME
  # http://metrics-influxdb.akkeris:8086
  # InfluxDB can be accessed via port 8086 on the following DNS name from within your cluster:
  # - http://metrics-influxdb.akkeris:8086
  # You can easily connect to the remote instance with your local influx cli. To forward the API port to localhost:8086 run the following:
  # - kubectl port-forward --namespace akkeris $(kubectl get pods --namespace akkeris -l app=metrics-influxdb -o jsonpath='{ .items[0].metadata.name }') 8086:8086
  # You can also connect to the influx cli from inside the container. To open a shell session in the InfluxDB pod run the following:
  # - kubectl exec -i -t --namespace akkeris $(kubectl get pods --namespace akkeris -l app=metrics-influxdb -o jsonpath='{.items[0].metadata.name}') /bin/sh
  # To tail the logs for the InfluxDB pod run the following:
  # - kubectl logs -f --namespace akkeris $(kubectl get pods --namespace akkeris -l app=metrics-influxdb -o jsonpath='{ .items[0].metadata.name }')
  # TODO: ingress? metrics.$DOMAIN
  # TODO: create a database for influx?
  # tested OK
}

function install_kafka() {
  helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
  helm install --name kafkalogs --namespace akkeris incubator/kafka --kube-context $CONTEXT_NAME
  # kafkalogs-zookeeper.akkeris:2181 kafkalogs-kafka.akkeris:9092
  # TODO fluentd setup to push logs?
}

function install_akkeris_deployments() {
  # ... BROKERS ...
  # region
  # apps-watcher
  # logshuttle  -> needs postgres, thus postgres broker akkeris/logshuttle:release-4
  # logsession  -> needs postgres, thus postgres broker akkeris/logshuttle:release-4
  # auth
  # controller
  # appkit (appsapi)
  # akkeris-ui (akkerisui)
}


function install_grafana() {
  # TODO: Install grafana, and dashboard templates.
}


function install_gcloud_akkeris_sites() {
  DEPLOYMENT=auth NAMESPACE=akkeris PORT=5000 HOST=auth.$DOMAIN create_gcloud_ssl_site
  DEPLOYMENT=appsapi NAMESPACE=akkeris PORT=5000 HOST=apps.$DOMAIN create_gcloud_ssl_site
  DEPLOYMENT=akkerisui NAMESPACE=akkeris PORT=5000 HOST=akkeris.$DOMAIN create_gcloud_ssl_site
}


function install_new_gcloud_and_letsencrypt() {
  gcloud config set project $PROJECT_ID
  gcloud config set compute/zone $REGION
  create_google_kubernetes
  kubectl create namespace akkeris --context $CONTEXT_NAME
  install_helm
  install_gcloud_letsencrypt_issuer
  install_vault
  install_registry
  install_jenkins
  install_influxdb
  install_kafka
  install_akkeris_deployments
  install_gcloud_akkeris_sites
  install_grafana
}


if [ "REGION" == "" ]; then 
  echo "The REGION variable must be set to your providers region."
  exit 1
fi
if [ "$EMAIL" == "" ]; then
  echo "The EMAIL variable must be set to the account on your provider"
  exit 1
fi

if [ "$PROVIDER" == "gcloud" ]; then
  if [ "$PROJECT_ID" == "" ]; then
    echo "The PROJECT_ID variable must be set to the project on your gcloud, see below:"
    echo 
    gcloud projects list
    exit 1
  fi

  install_new_gcloud_and_letsencrypt
fi

