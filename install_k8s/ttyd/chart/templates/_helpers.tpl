{{- define "ttyd.name" -}}
ttyd
{{- end }}

{{- define "ttyd.fullname" -}}
{{ include "ttyd.name" . }}
{{- end }}