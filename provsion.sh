
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
# CLUSTER_NAME.  export CLUSTER_NAME=kobayashi
# TODO: DNS?..

export CONTEXT_NAME="gke_${PROJECT_ID}_${REGION}_${CLUSTER_NAME}"
export GCLOUD_CLUSTER_VERSION=1.10.6-gke.2
export JENKINS_PASS=foozle

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
  acme:
    config:
    - dns01:
        provider: gcloud
      domains:
      - $HOST
EOF
  echo $certificate > /tmp/$DEPLOYMENT-cert.yml
  kubectl create  
  # TODO: wait to check it suucceeded? status.conditions[0].status = True, 
  gcloud compute addresses create $HOST --global

  read -d '' ingress <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata: 
  annotations:
      ingress.kubernetes.io/ssl-redirect: "true"
      kubernetes.io/ingress.global-static-ip-name: $HOST
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

  # TODO: create service explicitly for the load balancer?..
  # TODO: provision the DNS entry in gcloud -- gcloud dns record-sets list --zone public 
  #       what about the "pubilc" zone ? how do we verify the zone?
  #
  #       IP_ADDRESS=`gcloud compute addresses describe $HOST --global | grep 'address: 1.1.1.1'`
  #       rm -rf /tmp/dns-update.yml
  #       gcloud dns record-sets transaction start --zone public --transaction-file=/tmp/dns-update.yml
  #       gcloud dns record-sets transaction add --name $HOST. --type A --ttl 3600 --zone public "$IP_ADDRESS" --transaction-file=/tmp/dns-update.yml
  #       gcloud dns record-sets transaction execute --zone public --transaction-file=/tmp/dns-update.yml
  #       rm -rf /tmp/dns-update.yml
  #
}

function create_google_kubernetes {
  # TODO: shouuld we add --enable-cloud-monitoring ?? exising cluster must hve at least two nodes
  # TODO: we should ensure were 1.10.6 (-gke.2) at least?
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
  #   rbac.authorization.k8s.io/v1
  #   rbac.authorization.k8s.io/v1beta1
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
  # namespace must be the same as the helm install!
  kubectl create -f /tmp/vault-cluster.yml --namespace akkeris --context $CONTEXT_NAME
  # view logs: export POD_NAME=$(kubectl get pods --namespace akkeris -l "app=vault-operator,release=vault" -o jsonpath="{.items[0].metadata.name}")
  #.           kubectl logs $POD_NAME --namespace=akkeris
  kubectl -n akkeris get vault akkeris -o jsonpath='{.status.vaultStatus.sealed[0]}' | xargs -0 -I {} kubectl -n akkeris port-forward {} 8200 & 
  VAULT_ADDR=https://localhost:8200 vault init -tls-skip-verify
  # TODO: capture above? prompt user about entering keys below?
  # TODO: How do we test if unseal worked?
  # TODO: how do we check to make sure vault CLI is installed and v1.10~~
  VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify
  VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify
  VAULT_ADDR=https://localhost:8200 vault unseal -tls-skip-verify
  # TODO: make sure the outptu does not contain 'Unseal Progress' otherwise the key was entered wrong above somehow
  killall kubectl

  # TODO: ingress? vault.$DOMAIN
  # TODO: how do we tell it not to use TLS so we can control it on the ingress, or how do we give it a valid cert so it 
  #       isnt untrusted?
  # tested OK-ish
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

