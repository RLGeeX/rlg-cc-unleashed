# Kubernetes Manifest Generator - Reference Documentation

Detailed templates, examples, and patterns for creating production-ready Kubernetes manifests.

## Table of Contents

1. [Deployment Template](#deployment-template)
2. [Service Templates](#service-templates)
3. [ConfigMap Template](#configmap-template)
4. [Secret Template](#secret-template)
5. [PersistentVolumeClaim Template](#persistentvolumeclaim-template)
6. [Security Context](#security-context)
7. [Labels and Annotations](#labels-and-annotations)
8. [Common Patterns](#common-patterns)
9. [Validation Commands](#validation-commands)
10. [Troubleshooting](#troubleshooting)

---

## Deployment Template

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <app-name>
    app.kubernetes.io/instance: <instance-name>
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: <system-name>
    app.kubernetes.io/managed-by: kubectl
spec:
  replicas: 3
  selector:
    matchLabels:
      app: <app-name>
  template:
    metadata:
      labels:
        app: <app-name>
        version: <version>
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: <container-name>
        image: <image>:<tag>
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: <port>
          name: http
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
        env:
        - name: ENV_VAR
          value: "value"
        envFrom:
        - configMapRef:
            name: <app-name>-config
        - secretRef:
            name: <app-name>-secret
```

---

## Service Templates

### ClusterIP (internal only)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app: <app-name>
spec:
  type: ClusterIP
  selector:
    app: <app-name>
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
```

### LoadBalancer (external access)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app: <app-name>
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
spec:
  type: LoadBalancer
  selector:
    app: <app-name>
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
```

### NodePort

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  type: NodePort
  selector:
    app: <app-name>
  ports:
  - name: http
    port: 80
    targetPort: 8080
    nodePort: 30080
    protocol: TCP
```

---

## ConfigMap Template

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <app-name>-config
  namespace: <namespace>
data:
  APP_MODE: production
  LOG_LEVEL: info
  DATABASE_HOST: db.example.com
  # For config files
  app.properties: |
    server.port=8080
    server.host=0.0.0.0
    logging.level=INFO
```

---

## Secret Template

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <app-name>-secret
  namespace: <namespace>
type: Opaque
stringData:
  DATABASE_PASSWORD: "changeme"
  API_KEY: "secret-api-key"
  # For certificate files (replace with actual values)
  tls.crt: "<base64-encoded-certificate>"
  tls.key: "<base64-encoded-private-key>"
```

**Security considerations:**
- Never commit secrets to Git in plain text
- Use Sealed Secrets, External Secrets Operator, or Vault
- Rotate secrets regularly
- Use RBAC to limit secret access
- Consider using Secret type: `kubernetes.io/tls` for TLS secrets

---

## PersistentVolumeClaim Template

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <app-name>-data
  namespace: <namespace>
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 10Gi
```

**Mount in Deployment:**

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        volumeMounts:
        - name: data
          mountPath: /var/lib/app
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: <app-name>-data
```

---

## Security Context

**Pod-level security:**

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
```

**Container-level security:**

```yaml
containers:
- name: app
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
      - ALL
```

**Security checklist:**
- [ ] Run as non-root user
- [ ] Drop all capabilities
- [ ] Use read-only root filesystem
- [ ] Disable privilege escalation
- [ ] Set seccomp profile
- [ ] Use Pod Security Standards

---

## Labels and Annotations

**Standard labels (recommended):**

```yaml
metadata:
  labels:
    app.kubernetes.io/name: <app-name>
    app.kubernetes.io/instance: <instance-name>
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: <system-name>
    app.kubernetes.io/managed-by: kubectl
```

**Useful annotations:**

```yaml
metadata:
  annotations:
    description: "Application description"
    contact: "team@example.com"
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
```

---

## Common Patterns

### Pattern 1: Simple Stateless Web Application

**Components needed:**
- Deployment (3 replicas for HA)
- ClusterIP Service
- ConfigMap for configuration
- Secret for API keys
- HorizontalPodAutoscaler (optional)

### Pattern 2: Stateful Database Application

**Components needed:**
- StatefulSet (not Deployment)
- Headless Service
- PersistentVolumeClaim template
- ConfigMap for DB configuration
- Secret for credentials

### Pattern 3: Background Job or Cron

**Components needed:**
- CronJob or Job
- ConfigMap for job parameters
- Secret for credentials
- ServiceAccount with RBAC

### Pattern 4: Multi-Container Pod

**Components needed:**
- Deployment with multiple containers
- Shared volumes between containers
- Init containers for setup
- Service (if needed)

---

## File Organization

### Option 1: Single file with `---` separator

```yaml
# app-name.yaml
---
apiVersion: v1
kind: ConfigMap
...
---
apiVersion: v1
kind: Secret
...
---
apiVersion: apps/v1
kind: Deployment
...
---
apiVersion: v1
kind: Service
...
```

### Option 2: Separate files

```
manifests/
├── configmap.yaml
├── secret.yaml
├── deployment.yaml
├── service.yaml
└── pvc.yaml
```

### Option 3: Kustomize structure

```
base/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
└── configmap.yaml
overlays/
├── dev/
│   └── kustomization.yaml
└── prod/
    └── kustomization.yaml
```

---

## Validation Commands

```bash
# Dry-run validation
kubectl apply -f manifest.yaml --dry-run=client

# Server-side validation
kubectl apply -f manifest.yaml --dry-run=server

# Validate with kubeval
kubeval manifest.yaml

# Validate with kube-score
kube-score score manifest.yaml

# Check with kube-linter
kube-linter lint manifest.yaml
```

**Testing checklist:**
- [ ] Manifest passes dry-run validation
- [ ] All required fields are present
- [ ] Resource limits are reasonable
- [ ] Health checks are configured
- [ ] Security context is set
- [ ] Labels follow conventions
- [ ] Namespace exists or is created

---

## Troubleshooting

**Pods not starting:**
- Check image pull errors: `kubectl describe pod <pod-name>`
- Verify resource availability: `kubectl get nodes`
- Check events: `kubectl get events --sort-by='.lastTimestamp'`

**Service not accessible:**
- Verify selector matches pod labels: `kubectl get endpoints <service-name>`
- Check service type and port configuration
- Test from within cluster: `kubectl run debug --rm -it --image=busybox -- sh`

**ConfigMap/Secret not loading:**
- Verify names match in Deployment
- Check namespace
- Ensure resources exist: `kubectl get configmap,secret`
