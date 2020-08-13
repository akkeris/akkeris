# prechecks: $CLUSTER?, $VAULT_ADDR and $VAULT_TOKEN, $DOMAIN, AWS_SECRET_ACCESS_KEY, AWS_ACCESS_KEY_ID, AWS_REGION, EMAIL
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
helm install --name cert-manager --namespace cert-manager --version v0.12.0 --set=extraArgs={"--dns01-self-check-nameservers=8.8.8.8:53\,1.1.1.1:53"} --wait --timeout 600 jetstack/cert-manager
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.12.0/cert-manager.yaml
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
kubectl create namespace sites-system
kubectl label namespace akkeris-system istio-injection=disabled
helm install ./helm/akkeris-ingress-chart/ --name akkeris-ingress --namespace istio-system \
    --set=logging.zookeeper=kafkalogs-zookeeper.akkeris-system:2181 \
    --set=domain=$DOMAIN \
    --set=clusterissuer=letsencrypt \
    --set=name=$CLUSTER \
    --set=kubernetesapiurl=kubernetes.default \
    --set=kubernetestoken=$KUBE_TOKEN \
    --set=regionapiurl=http://region-api.akkeris-system \
    --set=regionapipassword=


