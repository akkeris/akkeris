#!/bin/bash

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

function delete_google_kubernetes {
  kubectl config use-context $CONTEXT_NAME
  gcloud container clusters delete $CLUSTER_NAME
}

function uninstall_helm {
  kubectl config use-context $CONTEXT_NAME
  kubectl delete serviceaccount --namespace kube-system tiller --context $CONTEXT_NAME
  kubectl delete clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller --context $CONTEXT_NAME
  helm reset --service-account tiller --kube-context $CONTEXT_NAME
}


function uninstall_kafka {
  helm del --purge kafkalogs --kube-context $CONTEXT_NAME
}

function uninstall_registry {
  helm del --purge registry --kube-context $CONTEXT_NAME
}

function uninstall_vault {
  kubectl delete vault akkeris -n default --context $CONTEXT_NAME
  helm del --purge vault --kube-context $CONTEXT_NAME
}

function uninstall_jenkins {
  helm del --purge jenkins --kube-context $CONTEXT_NAME
}

function uninstall_fluentd {
  kubectl delete -f ./logshuttle-fluentd/manifest.yml --context $CONTEXT_NAME
}

function uuninstall_influxdb {
  helm del --purge metrics --kube-context $CONTEXT_NAME
  # http://influxdb-influxdb.akkeris:8086
}

function delete_gcloud_letsencrypt_issuer {
  gcloud iam service-accounts delete letsencrypt@$PROJECT_ID.iam.gserviceaccount.com
  kubectl delete issuer letsencrypt -n akkeris
  gcloud projects remove-iam-policy-binding $PROJECT_ID --member serviceAccount:letsencrypt@$PROJECT_ID.iam.gserviceaccount.com --role roles/owner
}

function delete_gcloud_dns {
  rm -rf /tmp/dns-remove.yml
  gcloud dns record-sets transaction start --zone public --transaction-file=/tmp/dns-remove.yml
  export IP_ADDRESS=`kubectl get ingress jenkins -n akkeris -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --context $CONTEXT_NAME`
  gcloud dns record-sets transaction remove "$IP_ADDRESS" --name builds.$DOMAIN. --type A --ttl 3600 --zone public --transaction-file=/tmp/dns-remove.yml
  export IP_ADDRESS=`kubectl get ingress registry-docker-registry -n akkeris -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --context $CONTEXT_NAME`
  gcloud dns record-sets transaction remove "$IP_ADDRESS" --name registry.$DOMAIN. --type A --ttl 3600 --zone public --transaction-file=/tmp/dns-remove.yml
  gcloud dns record-sets transaction execute --zone public --transaction-file=/tmp/dns-remove.yml
  rm -rf /tmp/dns-remove.yml
}

function delete_gcloud_ipaddresses {
  gcloud compute addresses delete jenkins-akkeris-ingress --global
  gcloud compute addresses delete registry-docker-registry-akkeris-ingress --global
}

function delete_gcloud_ssl_site {
  export ESCAPED_HOST="$DEPLOYMENT-$NAMESPACE-ingress"
  export IP_ADDRESS=`kubectl get ingress $DEPLOYMENT -n akkeris -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
  kubectl delete ingress $DEPLOYMENT -n $NAMESPACE --context $CONTEXT_NAME
  kubectl delete service $DEPLOYMENT-lb -n $NAMESPACE --context $CONTEXT_NAME
  kubectl delete certificate $HOST -n $NAMESPACE --context $CONTEXT_NAME
  gcloud compute addresses delete $ESCAPED_HOST --global

  rm -rf /tmp/dns-update.yml
  gcloud dns record-sets transaction start --zone public --transaction-file=/tmp/dns-update.yml
  gcloud dns record-sets transaction remove --name $HOST. --type A --ttl 3600 --zone public "$IP_ADDRESS" --transaction-file=/tmp/dns-update.yml
  gcloud dns record-sets transaction execute --zone public --transaction-file=/tmp/dns-update.yml
  rm -rf /tmp/dns-update.yml
}

delete_gcloud_dns
delete_gcloud_letsencrypt_issuer
delete_google_kubernetes
delete_gcloud_ipaddresses
