# Clode Studio Kubernetes Deployment

This directory contains Kubernetes manifests for deploying Clode Studio in a Kubernetes cluster.

## Quick Start

### Prerequisites

- Kubernetes cluster (1.20+)
- kubectl configured
- NGINX Ingress Controller (optional, for ingress)
- cert-manager (optional, for TLS certificates)
- Storage class supporting ReadWriteOnce (e.g., `fast-ssd`)

### Deployment

1. **Apply all manifests at once:**
   ```bash
   kubectl apply -f k8s/
   ```

2. **Using Kustomize (recommended):**
   ```bash
   kubectl apply -k k8s/
   ```

3. **Step-by-step deployment:**
   ```bash
   # Create namespace
   kubectl apply -f k8s/namespace.yaml
   
   # Create storage
   kubectl apply -f k8s/pvc.yaml
   
   # Create configuration
   kubectl apply -f k8s/configmap.yaml
   
   # Deploy application
   kubectl apply -f k8s/deployment.yaml
   kubectl apply -f k8s/service.yaml
   
   # Set up external access (optional)
   kubectl apply -f k8s/ingress.yaml
   ```

## Configuration

### Environment Variables

Key configuration options in `configmap.yaml`:

- `CLODE_MODE`: Set to "headless" for server deployment
- `CLODE_WORKSPACE_PATH`: Path to workspace directory
- `RELAY_TYPE`: Type of relay server for remote access
- `NODE_ENV`: Node.js environment (production/development)

### Storage

Two persistent volume claims are created:

- `clode-studio-workspace` (10Gi): User workspace data
- `clode-studio-data` (5Gi): Application configuration and cache

### Ingress

Update the following in `ingress.yaml`:

- Replace `yourdomain.com` with your actual domain
- Configure TLS certificates if using cert-manager
- Adjust annotations for your ingress controller

## Scaling

### Horizontal Scaling

```bash
kubectl scale deployment clode-studio --replicas=3 -n clode-studio
```

### Vertical Scaling

Adjust resource limits in `deployment.yaml`:

```yaml
resources:
  limits:
    cpu: 4000m
    memory: 8Gi
  requests:
    cpu: 1000m
    memory: 2Gi
```

## Monitoring

### Health Checks

The deployment includes:

- **Liveness Probe**: Checks if container is running
- **Readiness Probe**: Checks if service is ready to receive traffic  
- **Startup Probe**: Allows extra time for initial startup

### Prometheus Integration

Annotations are included for Prometheus scraping:

```yaml
prometheus.io/scrape: "true"
prometheus.io/port: "3000"
prometheus.io/path: "/health"
```

## Security

### Pod Security

- Runs as non-root user (UID 1000)
- Read-only root filesystem where possible
- Drops all capabilities
- Seccomp profile applied

### Network Security

- ClusterIP services for internal communication
- Ingress with rate limiting and security headers
- TLS termination at ingress level

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n clode-studio
kubectl describe pod <pod-name> -n clode-studio
kubectl logs <pod-name> -n clode-studio
```

### Check Services

```bash
kubectl get services -n clode-studio
kubectl describe service clode-studio -n clode-studio
```

### Port Forward for Testing

```bash
kubectl port-forward service/clode-studio 3000:80 -n clode-studio
```

### Common Issues

1. **Storage Class Not Found**
   - Update `storageClassName` in `pvc.yaml`
   - Check available storage classes: `kubectl get storageclass`

2. **Image Pull Errors**
   - Verify image exists in registry
   - Check image pull secrets if using private registry

3. **Ingress Not Working**
   - Verify ingress controller is installed
   - Check ingress class name
   - Verify DNS configuration

## Customization

### Using Kustomize

Create overlays for different environments:

```bash
k8s/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── development/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   └── production/
│       ├── kustomization.yaml
│       └── patches/
```

### Environment-Specific Configurations

1. **Development:**
   - Single replica
   - Lower resource limits
   - Debug logging enabled

2. **Production:**
   - Multiple replicas
   - Higher resource limits
   - Security hardening
   - Monitoring enabled

## Backup and Recovery

### Backup Workspace Data

```bash
kubectl exec deployment/clode-studio -n clode-studio -- tar czf - /workspace | \
  kubectl exec -i backup-pod -- tar xzf - -C /backup/
```

### Restore from Backup

```bash
kubectl exec -i deployment/clode-studio -n clode-studio -- tar xzf - -C /workspace < backup.tar.gz
```

## Updates

### Rolling Update

```bash
kubectl set image deployment/clode-studio clode-studio=ghcr.io/haidar-ali/clode-studio:v1.2.0 -n clode-studio
```

### Check Rollout Status

```bash
kubectl rollout status deployment/clode-studio -n clode-studio
```

### Rollback

```bash
kubectl rollout undo deployment/clode-studio -n clode-studio
```