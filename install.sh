# prechecks: $CLUSTER?, $VAULT_ADDR and $VAULT_TOKEN, $DOMAIN, AWS_SECRET_ACCESS_KEY, AWS_ACCESS_KEY_ID, AWS_REGION, EMAIL, INFLUX, $DATABASE_URL <- without database at the end, $AWS_ACCOUNT_ID, $AWS_S3_KMS_KEY_ID, $AWS_ES_KMS_KEY_ID, $AWS_ES_SUBNET_IDS <- subnets separated by comma
# optional: APPS_PRIVATE_INGRESS, APPS_PUBLIC_INGRESS, SITES_PRIVATE_INGRESS, SITES_PUBLIC_INGRESS, NODEPORT setting?, NAGIOS_ADDRESS, $VAULT_PATHS
# CONTROLLER_TOKEN,  CONTROLLER_API

# TODO: Hobby db is required, create it now?
# TODO: service broker mock?

export CLUSTER=`kubectl config current-context`
kubectl create namespace akkeris-system
kubectl label namespace akkeris-system istio-injection=disabled
kubectl apply -n akkeris-system -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: akkeris
EOF
kubectl create clusterrolebinding akkeris-service-account --clusterrole=cluster-admin --serviceaccount=akkeris-system:akkeris
istioctl install -f ./istioctl/istio-1.6.7-profile-awsnlb.yml
kubectl --namespace kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller --upgrade
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm repo update
helm install --name kafkalogs incubator/kafka --namespace akkeris-system -f ./helm/kafka-values.yaml --wait
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install --name cert-manager --namespace cert-manager --version v0.15.0 --set=extraArgs={"--dns01-recursive-nameservers=8.8.8.8:53\,1.1.1.1:53"\,"--dns01-recursive-nameservers-only"} --wait --timeout 600 jetstack/cert-manager
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.0/cert-manager.yaml
export AWS_ACCESS_KEY_ID_B64=`echo -n $AWS_ACCESS_KEY_ID | base64`
export AWS_SECRET_ACCESS_KEY_B64=`echo -n $AWS_SECRET_ACCESS_KEY | base64`

kubectl apply -f - <<EOF
apiVersion: v1
data:
  secret-access-key: $AWS_SECRET_ACCESS_KEY_B64
kind: Secret
metadata:
  name: route53-svc-acct-secret
  namespace: cert-manager
type: Opaque
EOF

kubectl apply -f - <<EOF
apiVersion: v1
data:
  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID_B64}
  AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY_B64}
kind: Secret
metadata:
  name: akkeris-system-iam
  namespace: akkeris-system
type: Opaque
EOF

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod-private-key
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
    - dns01:
        route53:
          accessKeyID: $AWS_ACCESS_KEY_ID
          region: $AWS_REGION
          secretAccessKeySecretRef:
            key: secret-access-key
            name: route53-svc-acct-secret
EOF

export KUBE_TOKEN_NAME=`kubectl get secrets -n akkeris-system -o custom-columns=name:{.metadata.name} | grep akkeris | grep token`
export KUBE_TOKEN=`kubectl get secrets/$KUBE_TOKEN -o jsonpath={.data.token} -n akkeris-system`
export KUBE_TOKEN=`echo $KUBE_TOKEN | base64 -D`
kubectl create namespace sites-system
kubectl label namespace akkeris-system istio-injection=disabled
helm install ./helm/akkeris-ingress-chart/ --name akkeris-ingress --namespace istio-system \
    --set=logging.zookeeper=kafkalogs-zookeeper.akkeris-system:2181 \
    --set=domain=$DOMAIN \
    --set=clusterissuer=letsencrypt \
    --set=name=$CLUSTER \
    --set=kubernetesapiurl=https://kubernetes.default \
    --set=kubernetestoken=$KUBE_TOKEN \
    --set=regionapiurl=http://region-api.akkeris-system.svc.cluster.local \
    --set=regionapipassword=

if [ "$APPS_PRIVATE_INGRESS" == "" ]; then
	export APPS_PRIVATE_INGRESS=`kubectl get services/apps-private-ingressgateway -o 'jsonpath={.status.loadBalancer.ingress[0].hostname}' -n istio-system`
fi

if [ "$APPS_PUBLIC_INGRESS" == "" ]; then
	export APPS_PUBLIC_INGRESS=`kubectl get services/apps-public-ingressgateway -o 'jsonpath={.status.loadBalancer.ingress[0].hostname}' -n istio-system`
fi

if [ "$SITES_PRIVATE_INGRESS" == "" ]; then
	export SITES_PRIVATE_INGRESS=`kubectl get services/sites-private-ingressgateway -o 'jsonpath={.status.loadBalancer.ingress[0].hostname}' -n istio-system`
fi

if [ "$SITES_PUBLIC_INGRESS" == "" ]; then
	export SITES_PUBLIC_INGRESS=`kubectl get services/sites-public-ingressgateway -o 'jsonpath={.status.loadBalancer.ingress[0].hostname}' -n istio-system`
fi

if [ "$NAGIOS_ADDRESS" == "" ]; then
	export NAGIOS_ADDRESS="127.0.0.1:8081"
fi

if [ "$VAULT_PATHS" == "" ]; then
	export VAULT_PATHS="secret/dev,secret/qa,secret/stg,secret/stage,secret/prod"
fi

export IMAGE_PULL_SECRET="harbor.${DOMAIN}"
export VAULT_PREFIX="VAULT"

# TODO: install downpage
# TODO: createdb ${DATABASE_URL}/region-api
# TODO: createdb ${DATABASE_URL}/logshuttle

kubectl apply -f - <<EOF
apiVersion: v1
data:
  ALAMO_API_AUTH_PASSWORD: ""
  ALAMO_API_AUTH_USERNAME: ""
  ALAMO_INTERNAL_URL_TEMPLATE: https://{name}-{space}.${CLUSTER}i.${DOMAIN}/
  ALAMO_URL_TEMPLATE: https://{name}-{space}.${CLUSTER}.${DOMAIN}/
  APPS_PRIVATE_INTERNAL: istio://${APPS_PRIVATE_INGRESS}/istio-system/apps-private-ingressgateway
  APPS_PUBLIC_EXTERNAL: istio://${APPS_PUBLIC_INGRESS}/istio-system/apps-public-ingressgateway
  APPS_PUBLIC_INTERNAL: istio://${APPS_PUBLIC_INGRESS_INTERNAL}/istio-system/apps-public-ingressgateway
  DOMAIN_NAME: ${DOMAIN}
  ENABLE_AUTH: "false"
  EXTERNAL_DOMAIN: ${CLUSTER}.${DOMAIN}
  IMAGE_PULL_SECRET: ${IMAGE_PULL_SECRET}
  INFLUXDB_BROKER_URL: influx-api.akkeris-system.svc.cluster.local
  INFLUXDB_URL: http://${INFLUX}:8086
  INGRESS_DEBUG: "true"
  INTERNAL_DOMAIN: ${CLUSTER}i.${DOMAIN}
  KAFKA_BROKER_URL: http://kafka-api.akkeris-system.svc.cluster.local
  KAFKA_BROKERS: kafkalogs-0.kafkalogs-headless.akkeris-system.svc.cluster.local:9092,kafkalogs-1.kafkalogs-headless.akkeris-system.svc.cluster.local:9092,kafkalogs-2.kafkalogs-headless.akkeris-system.svc.cluster.local:9092
  MARTINI_ENV: production
  NAGIOS_ADDRESS: ${NAGIOS_ADDRESS}
  PITDB: ${DATABASE_URL}/region-api
  PORT: "3600"
  PROMETHEUS_URL: http://prometheus-server.prometheus
  RABBITMQ_BROKER_URL: rabbitmq-api.akkeris-system.svc.cluster.local
  REVISION_HISTORY_LIMIT: "10"
  SECRETS: ${VAULT_PATHS}
  SERVICES: http://database-broker-api.akkeris-system,http://elasticache-broker-api.akkeris-system,http://s3-broker-api.akkeris-system,http://elasticsearch-broker-api.akkeris-system,http://cloudfront-broker-api.akkeris-system,http://mongodb-broker-api.akkeris-system,http://rabbitmq-broker-api.akkeris-system
  SITES_PRIVATE_INTERNAL: istio://${SITES_PRIVATE_INGRESS}/istio-system/sites-private-ingressgateway
  SITES_PUBLIC_EXTERNAL: istio://${SITES_PUBLIC_INGRESS}/istio-system/sites-public-ingressgateway
  SITES_PUBLIC_INTERNAL: istio://${SITES_PUBLIC_INGRESS_INTERNAL}/istio-system/sites-public-ingressgateway
  VAULT_PREFIX: ${VAULT_PREFIX}
kind: ConfigMap
metadata:
  name: region-api
  namespace: akkeris-system
EOF

kubectl apply -f - <<EOF
apiVersion: v1
data:
  AUTH_KEY: ""
  KAFKA_HOSTS: kafkalogs-0.kafkalogs-headless.akkeris-system.svc.cluster.local:9092,kafkalogs-1.kafkalogs-headless.akkeris-system.svc.cluster.local:9092,kafkalogs-2.kafkalogs-headless.akkeris-system.svc.cluster.local:9092
  PORT: "5000"
  POSTGRES_URL: ${DATABASE_URL}/logshuttle
kind: ConfigMap
metadata:
  name: logshuttle
  namespace: akkeris-system
EOF

# TODO: create private/public record for ${DOMAIN} hostname: logsession-${CLUSTER}.${DOMAIN} A record to ${SITES_PUBLIC_INGRESS}.
kubectl apply -f - <<EOF
apiVersion: v1
data:
  AUTH_KEY: ""
  KAFKA_HOSTS: kafkalogs-0.kafkalogs-headless.akkeris-system.svc.cluster.local:9092,kafkalogs-1.kafkalogs-headless.akkeris-system.svc.cluster.local:9092,kafkalogs-2.kafkalogs-headless.akkeris-system.svc.cluster.local:9092
  PORT: "5000"
  POSTGRES_URL: ${DATABASE_URL}/logshuttle
  RUN_SESSION: "1"
  SESSION_URL: https://logsession-${CLUSTER}.${DOMAIN}
kind: ConfigMap
metadata:
  name: logsession
  namespace: akkeris-system
EOF

kubectl apply -f - <<EOF
apiVersion: v1
data:
  AWS_REGION: ${AWS_REGION}
  AWS_VPC_SECURITY_GROUPS: ${AWS_VPC_SECURITY_GROUPS}
  DATABASE_URL: ${DATABASE_URL}/database-broker
  NAME_PREFIX: ${CLUSTER}
kind: ConfigMap
metadata:
  name: database-broker
  namespace: akkeris-system
  selfLink: /api/v1/namespaces/akkeris-system/configmaps/database-broker
EOF

kubectl apply -f - <<EOF
apiVersion: v1
data:
  AWS_ACCOUNT_ID ${AWS_ACCOUNT_ID}
  AWS_KMS_KEY_ID: ${AWS_S3_KMS_KEY_ID}
  AWS_REGION: ${AWS_REGION}
  AWS_VPC_SECURITY_GROUPS: ${AWS_VPC_SECURITY_GROUPS}
  DATABASE_URL: ${DATABASE_URL}/s3-broker
  NAME_PREFIX: ${CLUSTER}
kind: ConfigMap
metadata:
  name: s3-broker
  namespace: akkeris-system
  selfLink: /api/v1/namespaces/akkeris-system/configmaps/s3-broker
EOF

kubectl apply -f - <<EOF
apiVersion: v1
data:
  AWS_REGION: ${AWS_REGION}
  AWS_VPC_SECURITY_GROUPS: ${AWS_VPC_SECURITY_GROUPS}
  DATABASE_URL: ${DATABASE_URL}/elasticache-broker
  ELASTICACHE_SECURITY_GROUP: ${AWS_VPC_SECURITY_GROUPS}
  MEMCACHED_SUBNET_GROUP: memcached-subnet-group
  NAME_PREFIX: ${CLUSTER}
  REDIS_SUBNET_GROUP: redis-subnet-group
  USE_KUBERNETES: "true"
kind: ConfigMap
metadata:
  namespace: akkeris-system
  name: elasticache-broker
  selfLink: /api/v1/namespaces/akkeris-system/configmaps/elasticache-broker
EOF

kubectl apply -f - <<EOF
apiVersion: v1
data:
  AWS_ACCOUNT_ID: ${AWS_ACCOUNT_ID}
  AWS_KMS_KEY_ID: ${AWS_ES_KMS_KEY_ID}
  AWS_REGION: ${AWS_REGION}
  AWS_SECURITY_GROUP_ID: ${AWS_VPC_SECURITY_GROUPS}
  AWS_SUBNET_ID: ${AWS_ES_SUBNET_IDS}
  DATABASE_URL: ${DATABASE_URL}/elasticsearch-broker
  NAME_PREFIX: ${CLUSTER}
  PORT: "9000"
kind: ConfigMap
metadata:
  name: elasticsearch-broker
  namespace: akkeris-system
  selfLink: /api/v1/namespaces/akkeris-system/configmaps/elasticsearch-broker
EOF

kubectl apply -f - <<EOF
apiVersion: v1
data:
  NOTIFY: https://${CONTROLLER_TOKEN}@${CONTROLLER_API}/events
kind: ConfigMap
metadata:
  name: apps-watcher
  namespace: akkeris-system
  selfLink: /api/v1/namespaces/akkeris-system/configmaps/apps-watcher
EOF

# TODO: ingress install w/ certificate for region api?

if [ "$FULL_DEPLOYMENT" == "true" ]; then

# TODO: Create ec2 build server?
# TODO: Create s3 bucket for the logs

export EC2_BUILD_SERVICE_IP="0.0.0.0"
export S3_AWS_BUCKET_NAME="buildshuttle-worker-$CLUSTER"

kubectl apply -f - <<EOF
apiVersion: v1
data:
  DEBUG: buildshuttle,buildshuttle-worker
  DOCKER_BUILD_IMAGE: akkeris/buildshuttle:release-84
  DOCKER_BUILD_SETTINGS: '{"host": "http://${EC2_BUILD_SERVICE_IP}", "port": "2375"}'
  MAXIMUM_PARALLEL_BUILDS: "4"
  PORT: "9000"
  S3_ACCESS_KEY: ${AWS_ACCESS_KEY_ID}
  S3_BUCKET: ${S3_AWS_BUCKET_NAME}
  S3_LOCATION: ${S3_AWS_BUCKET_NAME}.s3.amazonaws.com
  S3_REGION: ${AWS_REGION}
  S3_SECRET_KEY: ${AWS_SECRET_ACCESS_KEY}
  USE_KUBERNETES: "true"
kind: ConfigMap
metadata:
  name: buildshuttle
  namespace: akkeris-system
EOF

fi

