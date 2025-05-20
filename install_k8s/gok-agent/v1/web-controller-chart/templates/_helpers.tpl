{{/*
Expand the name of the chart.
*/}}
{{- define "web-controller-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}