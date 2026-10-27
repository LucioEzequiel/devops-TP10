{{- define "devops-portfolio.labels" -}}
app.kubernetes.io/name: devops-portfolio
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.config.appVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
