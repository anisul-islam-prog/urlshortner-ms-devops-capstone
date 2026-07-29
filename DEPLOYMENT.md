# Deployment Guide — Local Minikube (macOS M2)

This guide covers deploying the URL Shortener microservices stack on a local Minikube cluster.

## Prerequisites

| Tool | Version | Install Command |
|------|---------|-----------------|
| Docker Desktop | 29.x | `brew install --cask docker` |
| Minikube | 1.38+ | `brew install minikube` |
| kubectl | 1.30+ | `brew install kubectl` |
| Helm | 3.15+ | `brew install helm` |
| k6 | 0.54+ | `brew install k6` |

## 1. Start Minikube

```bash
minikube start \
  --driver=docker \
  --cpus=3 \
  --memory=5g \
  --disk-size=20g \
  --kubernetes-version=v1.30.0 \
  --addons=metrics-server,ingress,ingress-dns
```

Verify:

```bash
minikube status
kubectl get nodes
```

## 2. Point Docker to Minikube

All images must be built inside Minikube's Docker daemon (not Docker Desktop).

```bash
eval $(minikube -p minikube docker-env)
```

> To switch back to Docker Desktop later: `eval $(minikube -p minikube docker-env -u)`

## 3. Build Images

Build from the repo root using the `docker/` folder Dockerfiles:

```bash
TAG=$(git rev-parse --short HEAD)

docker build -t urlshortener-go:$TAG -f docker/go.Dockerfile .
docker build -t urlshortener-python:$TAG -f docker/python.Dockerfile .
docker build -t urlshortener-nodejs:$TAG -f docker/nodejs.Dockerfile .

# Verify images exist inside Minikube
minikube ssh -- docker images | grep urlshortener
```

## 4. Deploy with Helm

```bash
helm upgrade --install urlshortener ./helm/urlshortener \
  --namespace urlshortener \
  --create-namespace \
  --set global.imagePullPolicy=Never \
  --set goService.image.tag=$TAG \
  --set pythonService.image.tag=$TAG \
  --set nodeService.image.tag=$TAG
```

## 5. Verify Deployment

```bash
kubectl get pods -n urlshortener
kubectl get svc -n urlshortener
kubectl get ingress -n urlshortener
kubectl get hpa -n urlshortener
```

All pods should show `1/1 Running`.

## 6. Access the Application

### Start the tunnel (macOS requirement)

In a **separate terminal**, keep this running:

```bash
minikube tunnel
```

### Add local DNS

```bash
sudo sh -c 'echo "127.0.0.1 urlshortener.local" >> /etc/hosts'
```

### Test endpoints

```bash
# Dashboard
curl http://urlshortener.local/api/stats

# Create a short URL
curl -X POST http://urlshortener.local/create \
  -d "long_url=https://example.com" \
  -H "Content-Type: application/x-www-form-urlencoded"

# Test redirect (replace XXXXXX with actual short code)
curl -L -I http://urlshortener.local/r/XXXXXX
```

Open the dashboard in browser:

```bash
open http://urlshortener.local
```

## 7. Monitoring Stack

Deploy Prometheus + Grafana:

```bash
kubectl apply -f monitoring/prometheus-config.yaml
kubectl apply -f monitoring/kube-state-metrics.yaml
kubectl apply -f monitoring/grafana-deployment.yaml
```

Access Grafana:

```bash
kubectl port-forward svc/grafana 3001:3000 -n monitoring
# http://localhost:3001 | admin / admin
```

Access Prometheus:

```bash
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# http://localhost:9090
```

## 8. Load Testing

Run the k6 spike simulation:

```bash
k6 run k6/load-test.js
```

Watch auto-scaling in real time:

```bash
# Terminal 1
kubectl get hpa -n urlshortener -w

# Terminal 2
kubectl get pods -n urlshortener -w
```

## 9. NetworkPolicy (Bonus Security)

Apply zero-trust microsegmentation:

```bash
kubectl apply -f networkpolicy.yaml
```

Verify:

```bash
kubectl get networkpolicy -n urlshortener
```

## 10. Teardown

```bash
helm uninstall urlshortener -n urlshortener
kubectl delete namespace urlshortener
kubectl delete namespace monitoring
minikube stop
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `CreateContainerError` | Missing ConfigMap/Secret | Verify `configmap.yaml` and `secret.yaml` exist in `helm/urlshortener/templates/` |
| `ImagePullBackOff` | Image not in Minikube | Run `eval $(minikube -p minikube docker-env)` before `docker build` |
| `CrashLoopBackOff` | App code hardcodes `localhost:6380` | Ensure `REDIS_HOST` env var is read from ConfigMap |
| `connection refused` on `urlshortener.local` | `minikube tunnel` not running | Start `minikube tunnel` in a separate terminal |
| HPA shows `<unknown>` | metrics-server not enabled | `minikube addons enable metrics-server` |
| Grafana empty panels | Prometheus not scraping | Check targets at `http://localhost:9090/targets` |

## Architecture Notes

- **Images:** Built directly into Minikube (`imagePullPolicy: Never`)
- **Registry:** No DockerHub used — fully local
- **Ingress:** NGINX Ingress Controller with `minikube tunnel` (macOS requirement)
- **Storage:** SQLite (file-based) per pod via `emptyDir` volumes
- **Security:** Non-root containers + NetworkPolicy microsegmentation