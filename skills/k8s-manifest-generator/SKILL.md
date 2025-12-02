---
name: k8s-manifest-generator
description: Create production-ready Kubernetes manifests for Deployments, Services, ConfigMaps, and Secrets following best practices and security standards. Use when generating Kubernetes YAML manifests, creating K8s resources, or implementing production-grade Kubernetes configurations.
---

# Kubernetes Manifest Generator

Step-by-step guidance for creating production-ready Kubernetes manifests including Deployments, Services, ConfigMaps, Secrets, and PersistentVolumeClaims.

## When to Use

- Create new Kubernetes Deployment manifests
- Define Service resources for network connectivity
- Generate ConfigMap and Secret resources
- Create PersistentVolumeClaim manifests
- Follow Kubernetes best practices and naming conventions
- Implement resource limits, health checks, and security contexts

## Step-by-Step Workflow

### 1. Gather Requirements

**Questions to ask:**
- What is the application name and purpose?
- What container image and tag will be used?
- Does the application need persistent storage?
- What ports does the application expose?
- Are there any secrets or configuration files needed?
- What are the CPU and memory requirements?
- Does the application need to be exposed externally?

### 2. Create Deployment

**Key elements:**
- Resource requests and limits (always set)
- Liveness and readiness probes
- Specific image tags (never `:latest`)
- Security context for non-root users
- Labels for organization

See `reference.md` for complete deployment template.

### 3. Create Service

**Choose type based on exposure:**
- ClusterIP - Internal only
- LoadBalancer - External access
- NodePort - Development/testing

See `reference.md` for service templates.

### 4. Create ConfigMap

For non-sensitive configuration data.

See `reference.md` for configmap template.

### 5. Create Secret

For sensitive data (passwords, API keys, certificates).

**Security notes:**
- Never commit in plain text
- Use Sealed Secrets or Vault
- Rotate regularly
- Limit access with RBAC

See `reference.md` for secret template.

### 6. Create PersistentVolumeClaim (if needed)

For stateful applications requiring persistent storage.

See `reference.md` for PVC template.

### 7. Apply Security Best Practices

**Pod security context:**
- runAsNonRoot: true
- runAsUser: 1000
- fsGroup: 1000
- seccompProfile: RuntimeDefault

**Container security context:**
- allowPrivilegeEscalation: false
- readOnlyRootFilesystem: true
- capabilities.drop: ALL

See `reference.md` for complete security context examples.

### 8. Add Labels and Annotations

Use standard Kubernetes labels:
- app.kubernetes.io/name
- app.kubernetes.io/instance
- app.kubernetes.io/version
- app.kubernetes.io/component

### 9. Validate and Test

```bash
kubectl apply -f manifest.yaml --dry-run=client
kubectl apply -f manifest.yaml --dry-run=server
kube-score score manifest.yaml
```

---

## Best Practices Summary

| Practice | Description |
|----------|-------------|
| Resource limits | Prevents resource starvation |
| Health checks | Kubernetes can manage your app |
| Specific image tags | Avoid unpredictable deployments |
| Security contexts | Run as non-root, drop capabilities |
| ConfigMaps/Secrets | Separate config from code |
| Labels | Enable filtering and organization |
| Validate before applying | Use dry-run and validation tools |
| Version manifests | Keep in Git with version control |

---

## Related Skills

- `helm-chart-scaffolding` - For templating and packaging
- `gitops-workflow` - For automated deployments
- `k8s-security-policies` - For advanced security configurations

---

## References

See `reference.md` for:
- Complete Deployment template
- Service templates (ClusterIP, LoadBalancer, NodePort)
- ConfigMap template
- Secret template
- PersistentVolumeClaim template
- Security context examples
- Labels and annotations
- Common patterns
- File organization options
- Validation commands
- Troubleshooting guide
