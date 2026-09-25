# observability

Personal observability tooling, organized by target. Each approach lives in its
own self-contained folder so they can be added or removed independently.

## Layout

| Path | Target | Notes |
|------|--------|-------|
| `kubernetes/` | In-cluster Prometheus + Grafana | See the Kubernetes section below. |
| `docker-compose.yaml`, `prometheus.yaml` | Local host / docker-compose | Prometheus + Grafana for scraping things on `host.docker.internal`. |

Add new targets as sibling folders (e.g. `docker/`, `systemd/`, `baremetal/`)
and give each its own section in this README.

---

## Kubernetes

Layered, in-cluster Prometheus + Grafana in namespace `telemetry`. The layers
are removable so you can mix and match per project.

### Layers

| File (`kubernetes/`) | What it is | Depends on |
|------|-----------|------------|
| `cluster-monitoring.yaml` | Core: Prometheus + Grafana. Generic annotation-based pod scraping, core k8s scrapes (cadvisor/kubelet/apiserver/etcd), a Grafana dashboard sidecar, and a Prometheus datasource. Project agnostic. | nothing |
| `exporters.yaml` | Generic node + object metrics: node-exporter (DaemonSet) + kube-state-metrics. Reusable for any workload. | core |
| `camberfs-monitoring.yaml` | Just the CamberFS dashboard, as a labeled ConfigMap. | core (+ exporters for full data) |
| `control-plane-monitoring.yaml` | Control plane sizing dashboard (cadvisor/kubelet), as a labeled ConfigMap. | core |
| `grafana-external.yaml` | Optional extra external expose for Grafana. | core |
| `grafana-manifest.yaml` | Standalone Grafana in its own namespace (legacy, unrelated). | - |

Deploy what you need, in any order:

```
kubectl apply -f kubernetes/cluster-monitoring.yaml   # always
kubectl apply -f kubernetes/exporters.yaml            # node + object metrics
kubectl apply -f kubernetes/camberfs-monitoring.yaml  # camberfs dashboard
kubectl apply -f kubernetes/grafana-external.yaml     # optional external expose
```

Grafana: `http://<node-ip>:32000` (admin / admin). Prometheus: `http://<node-ip>:32090`.
NodePort Services show `EXTERNAL-IP: <none>`; reach them on any node's IP.

### How the plug-in model works

Adding monitoring for a project needs **no edits to the core files**:

- **Scraping** happens through the generic `kubernetes-pods` job. Annotate a pod
  and Prometheus scrapes it:

  ```yaml
  metadata:
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "8000"
      prometheus.io/path: "/metrics"   # default /metrics
  ```

  The scrape attaches `namespace`, `pod`, `node`, and `app` labels to every
  series. CamberFS pods already carry these annotations (set by its Helm chart).

- **Dashboards** are picked up by the Grafana sidecar. Ship any dashboard as a
  ConfigMap labeled `grafana_dashboard: "1"` in any namespace; it loads
  automatically. `camberfs-monitoring.yaml` is exactly this and nothing more.

So for a personal project: apply `cluster-monitoring.yaml` + `exporters.yaml`,
annotate the pods, and (optionally) drop in a labeled dashboard ConfigMap.
Removing a project is `kubectl delete -f <its dashboard file>`; the core and
exporters keep running.

### Reapplying after a change

Prometheus runs with `--web.enable-lifecycle`, so a config change reloads
without losing data:

```
kubectl -n telemetry port-forward svc/prometheus 9090:9090 &
curl -X POST http://127.0.0.1:9090/-/reload
```

The Grafana sidecar reloads dashboards live; a full restart is rarely needed:

```
kubectl -n telemetry rollout restart deploy/grafana
```

---

## Local (docker-compose)

Prometheus + Grafana on the host for scraping local processes:

```
docker compose up -d
```

Grafana on `http://localhost:3000`, Prometheus on `http://localhost:9090`.
Edit `prometheus.yaml` to point at your local targets (defaults to
`host.docker.internal:8000`).
