{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "akkeris.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create unified labels for akkeris components
*/}}
{{- define "akkeris.common.matchLabels" -}}
app: {{ template "akkeris.name" . }}
release: {{ .Release.Name }}
{{- end -}}

{{- define "akkeris.common.metaLabels" -}}
chart: {{ .Chart.Name }}-{{ .Chart.Version }}
heritage: {{ .Release.Service }}
{{- end -}}

{{- define "akkeris.appsWatcher.labels" -}}
{{ include "akkeris.appsWatcher.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.appsWatcher.matchLabels" -}}
component: {{ .Values.appsWatcher.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.buildshuttle.labels" -}}
{{ include "akkeris.buildshuttle.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.buildshuttle.matchLabels" -}}
component: {{ .Values.buildshuttle.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.databaseBroker.labels" -}}
{{ include "akkeris.databaseBroker.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.databaseBroker.matchLabels" -}}
component: {{ .Values.databaseBroker.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.elasticacheBroker.labels" -}}
{{ include "akkeris.elasticacheBroker.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.elasticacheBroker.matchLabels" -}}
component: {{ .Values.elasticacheBroker.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.elasticsearchBroker.labels" -}}
{{ include "akkeris.elasticsearchBroker.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.elasticsearchBroker.matchLabels" -}}
component: {{ .Values.elasticsearchBroker.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.logsession.labels" -}}
{{ include "akkeris.logsession.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.logsession.matchLabels" -}}
component: {{ .Values.logsession.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.logshuttle.labels" -}}
{{ include "akkeris.logshuttle.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.logshuttle.matchLabels" -}}
component: {{ .Values.logshuttle.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.metricsSample.labels" -}}
{{ include "akkeris.metricsSample.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.metricsSample.matchLabels" -}}
component: {{ .Values.metricsSample.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.metricsSyslogCollector.labels" -}}
{{ include "akkeris.metricsSyslogCollector.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.metricsSyslogCollector.matchLabels" -}}
component: {{ .Values.metricsSyslogCollector.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.regionApi.labels" -}}
{{ include "akkeris.regionApi.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.regionApi.matchLabels" -}}
component: {{ .Values.regionApi.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.routerMetrics.labels" -}}
{{ include "akkeris.routerMetrics.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.routerMetrics.matchLabels" -}}
component: {{ .Values.routerMetrics.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.s3Broker.labels" -}}
{{ include "akkeris.s3Broker.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.s3Broker.matchLabels" -}}
component: {{ .Values.s3Broker.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.serviceWatcherIstio.labels" -}}
{{ include "akkeris.serviceWatcherIstio.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.serviceWatcherIstio.matchLabels" -}}
component: {{ .Values.serviceWatcherIstio.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}

{{- define "akkeris.taas.labels" -}}
{{ include "akkeris.taas.matchLabels" . }}
{{ include "akkeris.common.metaLabels" . }}
{{- end -}}

{{- define "akkeris.taas.matchLabels" -}}
component: {{ .Values.taas.name | quote }}
{{ include "akkeris.common.matchLabels" . }}
{{- end -}}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "akkeris.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified apps-watcher name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.appsWatcher.fullname" -}}
{{- if .Values.appsWatcher.fullnameOverride -}}
{{- .Values.appsWatcher.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.appsWatcher.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.appsWatcher.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified buildshuttle name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.buildshuttle.fullname" -}}
{{- if .Values.buildshuttle.fullnameOverride -}}
{{- .Values.buildshuttle.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.buildshuttle.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.buildshuttle.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified database-broker name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.databaseBroker.fullname" -}}
{{- if .Values.databaseBroker.fullnameOverride -}}
{{- .Values.databaseBroker.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.databaseBroker.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.databaseBroker.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified elasticache-broker name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.elasticacheBroker.fullname" -}}
{{- if .Values.elasticacheBroker.fullnameOverride -}}
{{- .Values.elasticacheBroker.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.elasticacheBroker.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.elasticacheBroker.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified elasticsearch-broker name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.elasticsearchBroker.fullname" -}}
{{- if .Values.elasticsearchBroker.fullnameOverride -}}
{{- .Values.elasticsearchBroker.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.elasticsearchBroker.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.elasticsearchBroker.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified logsession name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.logsession.fullname" -}}
{{- if .Values.logsession.fullnameOverride -}}
{{- .Values.logsession.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.logsession.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.logsession.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified logshuttle name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.logshuttle.fullname" -}}
{{- if .Values.logshuttle.fullnameOverride -}}
{{- .Values.logshuttle.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.logshuttle.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.logshuttle.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified metrics-sample name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.metricsSample.fullname" -}}
{{- if .Values.metricsSample.fullnameOverride -}}
{{- .Values.metricsSample.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.metricsSample.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.metricsSample.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified metrics-syslog-collector name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.metricsSyslogCollector.fullname" -}}
{{- if .Values.metricsSyslogCollector.fullnameOverride -}}
{{- .Values.metricsSyslogCollector.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.metricsSyslogCollector.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.metricsSyslogCollector.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified region-api name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.regionApi.fullname" -}}
{{- if .Values.regionApi.fullnameOverride -}}
{{- .Values.regionApi.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.regionApi.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.regionApi.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified router-metrics name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.routerMetrics.fullname" -}}
{{- if .Values.routerMetrics.fullnameOverride -}}
{{- .Values.routerMetrics.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.routerMetrics.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.routerMetrics.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified s3-broker name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.s3Broker.fullname" -}}
{{- if .Values.s3Broker.fullnameOverride -}}
{{- .Values.s3Broker.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.s3Broker.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.s3Broker.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified service-watcher-istio name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.serviceWatcherIstio.fullname" -}}
{{- if .Values.serviceWatcherIstio.fullnameOverride -}}
{{- .Values.serviceWatcherIstio.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.serviceWatcherIstio.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.serviceWatcherIstio.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified taas name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "akkeris.taas.fullname" -}}
{{- if .Values.taas.fullnameOverride -}}
{{- .Values.taas.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.taas.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.taas.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for networkpolicy.
*/}}
{{- define "akkeris.networkPolicy.apiVersion" -}}
{{- if semverCompare ">=1.4-0, <1.7-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "extensions/v1beta1" -}}
{{- else if semverCompare "^1.7-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "networking.k8s.io/v1" -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the region-api component
*/}}
{{- define "akkeris.serviceAccountName.akkeris" -}}
{{- if .Values.serviceAccounts.akkeris.create -}}
    {{ default (include "akkeris.fullname" .) .Values.serviceAccounts.akkeris.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccounts.akkeris.name }}
{{- end -}}
{{- end -}}
