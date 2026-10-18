# Panel de costo observado

Requiere `gcloud` con sesión iniciada (`gcloud auth login`). Proyecto TEST: `ingresoya-e5115`.

```powershell
gcloud logging metrics create iya_observed_reads --config-from-file=monitoring/log_metric_reads.yaml --project ingresoya-e5115
gcloud logging metrics create iya_duration_ms --config-from-file=monitoring/log_metric_duration.yaml --project ingresoya-e5115
gcloud monitoring dashboards create --config-from-file=monitoring/cost_dashboard.json --project ingresoya-e5115
```

Las métricas basadas en logs solo cuentan desde que se crean; el histórico se
consulta con `node tools/cost_report.js` desde `functions/`.
