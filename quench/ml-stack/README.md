# Quenchworks ml-stack

A machine-learning workbench in one install: JupyterHub notebooks, the MLflow
tracking server and model registry, and Label Studio for data labeling. Every
QuenchWorks image runs nonroot, is pinned by digest and cosign-signed.

| Component | Service | Notes |
|---|---|---|
| JupyterHub | `ml-jupyterhub-proxy-public:80` | One notebook pod per user, `MLFLOW_TRACKING_URI` preset |
| MLflow | `ml-mlflow:5000` | Bundled PostgreSQL, artifacts on a PVC, no login |
| Label Studio | `ml-label-studio:8080` | SQLite on its data PVC |

## Install

```bash
helm install ml oci://ghcr.io/quenchworks/charts/ml-stack -n ml --create-namespace
```

Names are fixed (`ml-*`), so install one stack per namespace. In a notebook,
after `pip install mlflow`, `mlflow.log_metric("loss", 0.1)` reaches this MLflow
with no tracking-URI setup.

## Values

Each component takes its own chart's values under its key: `mlflow.*`,
`jupyterhub.*`, `label-studio.*`. Turn one off with `<key>.enabled=false`.

- Label Studio uses SQLite here, because its bundled PostgreSQL would take the
  same `<release>-postgresql` name as MLflow's. For PostgreSQL, set
  `label-studio.externalDatabase.*`.
- JupyterHub's notebook image is Jupyter's own `base-notebook` (not a QuenchWorks
  image). Set `jupyterhub.singleuser.image` to one with your libraries and `mlflow`.
- MLflow has no authentication. Its NetworkPolicy admits only pods in the
  namespace; put an authenticating proxy in front before exposing it.
