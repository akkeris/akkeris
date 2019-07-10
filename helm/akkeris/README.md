# Akkeris

Akkeris, a kubernetes based PaaS, is a powerful platform for managing applications and their resources.

## TL;DR;

```console
$ helm install ./helm/akkeris
```

## Introduction

This chart bootstraps an [Akkeris](https://beta.akkeris.io/#) deployment on a Kubernetes cluster using the Helm package manager.

## Prerequisites

* Kubernetes 1.6+ with Beta APIs enabled
* Postgres Database Server
* S3 bucket or compatible storage driver
* Istio & Certmanager

## Installing the Chart

To install the chart with the release name `my-release`:
```console
$ helm install --name my-release ./helm/akkeris
```

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```console
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

Parameter | Description | Default
--------- | ----------- | -------
`vault.address` | vault url | `vault.akkeris-system.svc.cluster.local`
`vault.token` | access token | `null`
`aws.accessKeyID` | aws user/role access key | `null`
`aws.secretAccessKey` | aws user/role secret key | `null`
`aws.region` | region aws vpc is located | `us-west-2`
`appsWatcher.name` | apps-watcher container name | `apps-watcher`
`appsWatcher.image.repository` | apps-watcher container image repository | `akkeris/apps-watcher`
`appsWatcher.image.tag` | apps-watcher container image tag | `release-12`
`appsWatcher.image.pullPolicy` | apps-watcher container image pull policy | `IfNotPresent`
`appsWatcher.nodeSelector` | node labels for apps-watcher pod assignment | `{}`
`appsWatcher.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`appsWatcher.affinity` | pod affinity | `{}`
`appsWatcher.schedulerName` | apps-watcher alternate scheduler name | `nill`
`appsWatcher.podAnnotations` | annotations to be added to apps-watcher pods | `{}`
`appsWatcher.replicaCount` | desired number of apps-watcher pods | `1`
`appsWatcher.priorityClassName` | apps-watcher priorityClassName | `nill`
`appsWatcher.resources` | apps-watcher pod resource requests & limits | `{}`
`appsWatcher.securityContext` | Custom security context for apps-watcher containers | `{}`
`buildshuttle.name` | buildshuttle container name | `buildshuttle`
`buildshuttle.image.repository` | buildshuttle container image repository | `akkeris/buildshuttle`
`buildshuttle.image.tag` | buildshuttle container image tag | `release-72`
`buildshuttle.image.pullPolicy` | buildshuttle container image pull policy | `IfNotPresent`
`buildshuttle.nodeSelector` | node labels for buildshuttle pod assignment | `{}`
`buildshuttle.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`buildshuttle.affinity` | pod affinity | `{}`
`buildshuttle.schedulerName` | buildshuttle alternate scheduler name | `nill`
`buildshuttle.podAnnotations` | annotations to be added to buildshuttle pods | `{}`
`buildshuttle.replicaCount` | desired number of buildshuttle pods | `1`
`buildshuttle.priorityClassName` | buildshuttle priorityClassName | `nill`
`buildshuttle.resources` | buildshuttle pod resource requests & limits | `{}`
`buildshuttle.securityContext` | Custom security context for buildshuttle containers | `{}`
`buildshuttle.service.annotations` | annotations for buildshuttle service | `{}`
`buildshuttle.service.clusterIP` | internal buildshuttle cluster service IP | `""`
`buildshuttle.service.servicePort` | buildshuttle service port | `80`
`buildshuttle.service.type` | type of buildshuttle service to create | `NodePort`
`databaseBroker.name` | database-broker container name | `database-broker`
`databaseBroker.image.repository` | database-broker container image repository | `akkeris/database-broker`
`databaseBroker.image.tag` | database-broker container image tag | `release-38`
`databaseBroker.image.pullPolicy` | database-broker container image pull policy | `IfNotPresent`
`databaseBroker.ingress.enabled` | If true, database-broker Ingress will be created | `false`
`databaseBroker.ingress.annotations` | database-broker Ingress annotations | `{}`
`databaseBroker.ingress.hosts` | database-broker Ingress host names | `[]`
`databaseBroker.ingress.tls` | database-broker Ingress TLS configuration (YAML) | `[]`
`databaseBroker.nodeSelector` | node labels for database-broker pod assignment | `{}`
`databaseBroker.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`databaseBroker.affinity` | pod affinity | `{}`
`databaseBroker.schedulerName` | database-broker alternate scheduler name | `nill`
`databaseBroker.podAnnotations` | annotations to be added to database-broker pods | `{}`
`databaseBroker.replicaCount` | desired number of database-broker pods | `1`
`databaseBroker.priorityClassName` | database-broker priorityClassName | `nill`
`databaseBroker.resources` | database-broker pod resource requests & limits | `{}`
`databaseBroker.securityContext` | Custom security context for database-broker containers | `{}`
`databaseBroker.service.annotations` | annotations for database-broker service | `{}`
`databaseBroker.service.clusterIP` | internal database-broker cluster service IP | `""`
`databaseBroker.service.servicePort` | database-broker service port | `80`
`databaseBroker.service.type` | type of database-broker service to create | `NodePort`
`elasticacheBroker.name` | elasticache-broker container name | `elasticache-broker`
`elasticacheBroker.image.repository` | elasticache-broker container image repository | `akkeris/elasticache-broker`
`elasticacheBroker.image.tag` | elasticache-broker container image tag | `release-6`
`elasticacheBroker.image.pullPolicy` | elasticache-broker container image pull policy | `IfNotPresent`
`elasticacheBroker.ingress.enabled` | If true, elasticache-broker Ingress will be created | `false`
`elasticacheBroker.ingress.annotations` | elasticache-broker Ingress annotations | `{}`
`elasticacheBroker.ingress.hosts` | elasticache-broker Ingress host names | `[]`
`elasticacheBroker.ingress.tls` | elasticache-broker Ingress TLS configuration (YAML) | `[]`
`elasticacheBroker.nodeSelector` | node labels for elasticache-broker pod assignment | `{}`
`elasticacheBroker.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`elasticacheBroker.affinity` | pod affinity | `{}`
`elasticacheBroker.schedulerName` | elasticache-broker alternate scheduler name | `nill`
`elasticacheBroker.podAnnotations` | annotations to be added to elasticache-broker pods | `{}`
`elasticacheBroker.replicaCount` | desired number of elasticache-broker pods | `1`
`elasticacheBroker.priorityClassName` | elasticache-broker priorityClassName | `nill`
`elasticacheBroker.resources` | elasticache-broker pod resource requests & limits | `{}`
`elasticacheBroker.securityContext` | Custom security context for elasticache-broker containers | `{}`
`elasticacheBroker.service.annotations` | annotations for elasticache-broker service | `{}`
`elasticacheBroker.service.clusterIP` | internal elasticache-broker cluster service IP | `""`
`elasticacheBroker.service.servicePort` | elasticache-broker service port | `80`
`elasticacheBroker.service.type` | type of elasticache-broker service to create | `NodePort`
`elasticsearchBroker.name` | elasticsearch-broker container name | `elasticsearch-broker`
`elasticsearchBroker.image.repository` | elasticsearch-broker container image repository | `akkeris/elasticsearch-broker`
`elasticsearchBroker.image.tag` | elasticsearch-broker container image tag | `release-2`
`elasticsearchBroker.image.pullPolicy` | elasticsearch-broker container image pull policy | `IfNotPresent`
`elasticsearchBroker.nodeSelector` | node labels for elasticsearch-broker pod assignment | `{}`
`elasticsearchBroker.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`elasticsearchBroker.affinity` | pod affinity | `{}`
`elasticsearchBroker.schedulerName` | elasticsearch-broker alternate scheduler name | `nill`
`elasticsearchBroker.podAnnotations` | annotations to be added to elasticsearch-broker pods | `{}`
`elasticsearchBroker.replicaCount` | desired number of elasticsearch-broker pods | `1`
`elasticsearchBroker.priorityClassName` | elasticsearch-broker priorityClassName | `nill`
`elasticsearchBroker.resources` | elasticsearch-broker pod resource requests & limits | `{}`
`elasticsearchBroker.securityContext` | Custom security context for elasticsearch-broker containers | `{}`
`elasticsearchBroker.service.annotations` | annotations for elasticsearch-broker service | `{}`
`elasticsearchBroker.service.clusterIP` | internal elasticsearch-broker cluster service IP | `""`
`elasticsearchBroker.service.servicePort` | elasticsearch-broker service port | `80`
`elasticsearchBroker.service.type` | type of elasticsearch-broker service to create | `NodePort`
`logsession.name` | logsession container name | `logsession`
`logsession.image.repository` | logsession container image repository | `akkeris/logsession`
`logsession.image.tag` | logsession container image tag | `release-38`
`logsession.image.pullPolicy` | logsession container image pull policy | `IfNotPresent`
`logsession.ingress.enabled` | If true, logsession Ingress will be created | `false`
`logsession.ingress.annotations` | logsession Ingress annotations | `{}`
`logsession.ingress.hosts` | logsession Ingress host names | `[]`
`logsession.ingress.tls` | logsession Ingress TLS configuration (YAML) | `[]`
`logsession.nodeSelector` | node labels for logsession pod assignment | `{}`
`logsession.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`logsession.affinity` | pod affinity | `{}`
`logsession.schedulerName` | logsession alternate scheduler name | `nill`
`logsession.podAnnotations` | annotations to be added to logsession pods | `{}`
`logsession.replicaCount` | desired number of logsession pods | `1`
`logsession.priorityClassName` | logsession priorityClassName | `nill`
`logsession.resources` | logsession pod resource requests & limits | `{}`
`logsession.securityContext` | Custom security context for logsession containers | `{}`
`logsession.service.annotations` | annotations for logsession service | `{}`
`logsession.service.clusterIP` | internal logsession cluster service IP | `""`
`logsession.service.servicePort` | logsession service port | `80`
`logsession.service.type` | type of logsession service to create | `NodePort`
`logshuttle.name` | logshuttle container name | `logshuttle`
`logshuttle.image.repository` | logshuttle container image repository | `akkeris/logshuttle`
`logshuttle.image.tag` | logshuttle container image tag | `release-9`
`logshuttle.image.pullPolicy` | logshuttle container image pull policy | `IfNotPresent`
`logshuttle.nodeSelector` | node labels for logshuttle pod assignment | `{}`
`logshuttle.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`logshuttle.affinity` | pod affinity | `{}`
`logshuttle.schedulerName` | logshuttle alternate scheduler name | `nill`
`logshuttle.podAnnotations` | annotations to be added to logshuttle pods | `{}`
`logshuttle.replicaCount` | desired number of logshuttle pods | `1`
`logshuttle.priorityClassName` | logshuttle priorityClassName | `nill`
`logshuttle.resources` | logshuttle pod resource requests & limits | `{}`
`logshuttle.securityContext` | Custom security context for logshuttle containers | `{}`
`logshuttle.service.annotations` | annotations for logshuttle service | `{}`
`logshuttle.service.clusterIP` | internal logshuttle cluster service IP | `""`
`logshuttle.service.servicePort` | logshuttle service port | `80`
`logshuttle.service.type` | type of logshuttle service to create | `NodePort`
`metricsSample.name` | metrics-sample container name | `metrics-sample`
`metricsSample.image.repository` | metrics-sample container image repository | `akkeris/metrics-sample`
`metricsSample.image.tag` | metrics-sample container image tag | `release-3`
`metricsSample.image.pullPolicy` | metrics-sample container image pull policy | `IfNotPresent`
`metricsSample.nodeSelector` | node labels for metrics-sample pod assignment | `{}`
`metricsSample.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`metricsSample.affinity` | pod affinity | `{}`
`metricsSample.schedulerName` | metrics-sample alternate scheduler name | `nill`
`metricsSample.podAnnotations` | annotations to be added to metrics-sample pods | `{}`
`metricsSample.replicaCount` | desired number of metrics-sample pods | `1`
`metricsSample.priorityClassName` | metrics-sample priorityClassName | `nill`
`metricsSample.resources` | metrics-sample pod resource requests & limits | `{}`
`metricsSample.securityContext` | Custom security context for metrics-sample containers | `{}`
`metricsSyslogCollector.name` | metrics-syslog-collector container name | `metrics-syslog-collector`
`metricsSyslogCollector.image.repository` | metrics-syslog-collector container image repository | `akkeris/metrics-syslog-collector`
`metricsSyslogCollector.image.tag` | metrics-syslog-collector container image tag | `pre-release-2`
`metricsSyslogCollector.image.pullPolicy` | metrics-syslog-collector container image pull policy | `IfNotPresent`
`metricsSyslogCollector.nodeSelector` | node labels for metrics-syslog-collector pod assignment | `{}`
`metricsSyslogCollector.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`metricsSyslogCollector.affinity` | pod affinity | `{}`
`metricsSyslogCollector.schedulerName` | metrics-syslog-collector alternate scheduler name | `nill`
`metricsSyslogCollector.podAnnotations` | annotations to be added to metrics-syslog-collector pods | `{}`
`metricsSyslogCollector.replicaCount` | desired number of metrics-syslog-collector pods | `1`
`metricsSyslogCollector.priorityClassName` | metrics-syslog-collector priorityClassName | `nill`
`metricsSyslogCollector.resources` | metrics-syslog-collector pod resource requests & limits | `{}`
`metricsSyslogCollector.securityContext` | Custom security context for metrics-syslog-collector containers | `{}`
`metricsSyslogCollector.service.annotations` | annotations for metrics-syslog-collector service | `{}`
`metricsSyslogCollector.service.clusterIP` | internal metrics-syslog-collector cluster service IP | `""`
`metricsSyslogCollector.service.servicePort` | metrics-syslog-collector service port | `80`
`metricsSyslogCollector.service.type` | type of metrics-syslog-collector service to create | `NodePort`
`regionApi.name` | region-api container name | `region-api`
`regionApi.image.repository` | region-api container image repository | `akkeris/region-api`
`regionApi.image.tag` | region-api container image tag | `release-38`
`regionApi.image.pullPolicy` | region-api container image pull policy | `IfNotPresent`
`regionApi.ingress.enabled` | If true, region-api Ingress will be created | `false`
`regionApi.ingress.annotations` | region-api Ingress annotations | `{}`
`regionApi.ingress.hosts` | region-api Ingress host names | `[]`
`regionApi.ingress.tls` | region-api Ingress TLS configuration (YAML) | `[]`
`regionApi.nodeSelector` | node labels for region-api pod assignment | `{}`
`regionApi.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`regionApi.affinity` | pod affinity | `{}`
`regionApi.schedulerName` | region-api alternate scheduler name | `nill`
`regionApi.podAnnotations` | annotations to be added to region-api pods | `{}`
`regionApi.replicaCount` | desired number of region-api pods | `1`
`regionApi.priorityClassName` | region-api priorityClassName | `nill`
`regionApi.resources` | region-api pod resource requests & limits | `{}`
`regionApi.securityContext` | Custom security context for region-api containers | `{}`
`regionApi.service.annotations` | annotations for region-api service | `{}`
`regionApi.service.clusterIP` | internal region-api cluster service IP | `""`
`regionApi.service.servicePort` | region-api service port | `80`
`regionApi.service.type` | type of region-api service to create | `NodePort`
`routerMetrics.name` | router-metrics container name | `router-metrics`
`routerMetrics.image.repository` | router-metrics container image repository | `akkeris/router-metrics`
`routerMetrics.image.tag` | router-metrics container image tag | `release-5`
`routerMetrics.image.pullPolicy` | router-metrics container image pull policy | `IfNotPresent`
`routerMetrics.nodeSelector` | node labels for router-metrics pod assignment | `{}`
`routerMetrics.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`routerMetrics.affinity` | pod affinity | `{}`
`routerMetrics.schedulerName` | router-metrics alternate scheduler name | `nill`
`routerMetrics.podAnnotations` | annotations to be added to router-metrics pods | `{}`
`routerMetrics.replicaCount` | desired number of router-metrics pods | `1`
`routerMetrics.priorityClassName` | router-metrics priorityClassName | `nill`
`routerMetrics.resources` | router-metrics pod resource requests & limits | `{}`
`routerMetrics.securityContext` | Custom security context for router-metrics containers | `{}`
`s3Broker.enabled` | If true, create s3-broker | `false`
`s3Broker.name` | s3-broker container name | `s3-broker`
`s3Broker.image.repository` | s3-broker container image repository | `akkeris/s3-broker`
`s3Broker.image.tag` | s3-broker container image tag | `release-6`
`s3Broker.image.pullPolicy` | s3-broker container image pull policy | `IfNotPresent`
`s3Broker.ingress.enabled` | If true, s3-broker Ingress will be created | `false`
`s3Broker.ingress.annotations` | s3-broker Ingress annotations | `{}`
`s3Broker.ingress.hosts` | s3-broker Ingress host names | `[]`
`s3Broker.ingress.tls` | s3-broker Ingress TLS configuration (YAML) | `[]`
`s3Broker.nodeSelector` | node labels for s3-broker pod assignment | `{}`
`s3Broker.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`s3Broker.affinity` | pod affinity | `{}`
`s3Broker.schedulerName` | s3-broker alternate scheduler name | `nill`
`s3Broker.podAnnotations` | annotations to be added to s3-broker pods | `{}`
`s3Broker.replicaCount` | desired number of s3-broker pods | `1`
`s3Broker.priorityClassName` | s3-broker priorityClassName | `nill`
`s3Broker.resources` | s3-broker pod resource requests & limits | `{}`
`s3Broker.securityContext` | Custom security context for s3-broker containers | `{}`
`s3Broker.service.annotations` | annotations for s3-broker service | `{}`
`s3Broker.service.clusterIP` | internal s3-broker cluster service IP | `""`
`s3Broker.service.servicePort` | s3-broker service port | `80`
`s3Broker.service.type` | type of s3-broker service to create | `NodePort`
`serviceWatcherIstio.name` | service-watcher-istio container name | `service-watcher-istio`
`serviceWatcherIstio.image.repository` | service-watcher-istio container image repository | `akkeris/service-watcher-istio`
`serviceWatcherIstio.image.tag` | service-watcher-istio container image tag | `release-12`
`serviceWatcherIstio.image.pullPolicy` | service-watcher-istio container image pull policy | `IfNotPresent`
`serviceWatcherIstio.nodeSelector` | node labels for service-watcher-istio pod assignment | `{}`
`serviceWatcherIstio.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`serviceWatcherIstio.affinity` | pod affinity | `{}`
`serviceWatcherIstio.schedulerName` | service-watcher-istio alternate scheduler name | `nill`
`serviceWatcherIstio.podAnnotations` | annotations to be added to service-watcher-istio pods | `{}`
`serviceWatcherIstio.replicaCount` | desired number of service-watcher-istio pods | `1`
`serviceWatcherIstio.priorityClassName` | service-watcher-istio priorityClassName | `nill`
`serviceWatcherIstio.resources` | service-watcher-istio pod resource requests & limits | `{}`
`serviceWatcherIstio.securityContext` | Custom security context for service-watcher-istio containers | `{}`
`taas.enabled` | If true, create taas | `false`
`taas.name` | taas container name | `taas`
`taas.image.repository` | taas container image repository | `akkeris/taas`
`taas.image.tag` | taas container image tag | `oneoffpod-vs-job-64`
`taas.image.pullPolicy` | taas container image pull policy | `IfNotPresent`
`taas.ingress.enabled` | If true, taas Ingress will be created | `false`
`taas.ingress.annotations` | taas Ingress annotations | `{}`
`taas.ingress.hosts` | taas Ingress host names | `[]`
`taas.ingress.tls` | taas Ingress TLS configuration (YAML) | `[]`
`taas.nodeSelector` | node labels for taas pod assignment | `{}`
`taas.tolerations` | node taints to tolerate (requires Kubernetes >= 1.6) | `[]`
`taas.affinity` | pod affinity | `{}`
`taas.schedulerName` | taas alternate scheduler name | `nill`
`taas.podAnnotations` | annotations to be added to taas pods | `{}`
`taas.replicaCount` | desired number of taas pods | `1`
`taas.priorityClassName` | taas priorityClassName | `nill`
`taas.resources` | taas pod resource requests & limits | `{}`
`taas.securityContext` | Custom security context for taas containers | `{}`
`taas.service.annotations` | annotations for taas service | `{}`
`taas.service.clusterIP` | internal taas cluster service IP | `""`
`taas.service.servicePort` | taas service port | `80`
`taas.service.type` | type of taas service to create | `NodePort`

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```console
$ helm install stable/akkeris --name my-release \
    --set vault.address="vault.example.com"
```

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
$ helm install stable/akkeris --name my-release -f values.yaml
```

> **Tip**: You can use the default [values.yaml](values.yaml)

## RBAC Configuration

## Configmap Values

There are some required values and permissions required for Akkeris to work with your cloud provider and it's brokers.


## Istio Configuration
