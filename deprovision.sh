
function delete_google_kubernetes {
	kubectl config use-context $CLUSTER_NAME
	gcloud container clusters delete $CLUSTER_NAME
}

function uninstall_helm() {
	kubectl config use-context $CONTEXT_NAME
	kubectl delete serviceaccount --namespace kube-system tiller --context $CONTEXT_NAME
	kubectl delete clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller --context $CONTEXT_NAME
	helm reset --service-account tiller --kube-context $CONTEXT_NAME
}


function uninstall_kafka() {
	helm del --purge kafkalogs --kube-context $CONTEXT_NAME
}

function uninstall_registry() {
	helm del --purge registry --kube-context $CONTEXT_NAME
}

function uninstall_vault() {
	kubectl delete vault akkeris -n default --context $CONTEXT_NAME
	helm del --purge vault --kube-context $CONTEXT_NAME
}

function uninstall_jenkins() {
	helm del --purge jenkins --kube-context $CONTEXT_NAME
}

function uuninstall_influxdb() {
 	helm del --purge metrics --kube-context $CONTEXT_NAME
 	# http://influxdb-influxdb.akkeris:8086
}

function delete_gcloud_letsencrypt_issuer {
	gcloud iam service-accounts delete letsencrypt@$PROJECT_ID.iam.gserviceaccount.com
	kubectl delete issuer letsencrypt -n akkeris
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


function uninstall_akkeris_sites() {
}