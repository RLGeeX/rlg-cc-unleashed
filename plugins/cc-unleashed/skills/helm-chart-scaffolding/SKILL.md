---
name: helm-chart-scaffolding
description: Design, organize, and manage Helm charts for templating and packaging Kubernetes applications with reusable configurations. Use when creating Helm charts, packaging Kubernetes applications, or implementing templated deployments.
---

# Helm Chart Scaffolding

Comprehensive guidance for creating, organizing, and managing Helm charts for packaging and deploying Kubernetes applications.

## When to Use

- Create new Helm charts from scratch
- Package Kubernetes applications for distribution
- Manage multi-environment deployments with Helm
- Implement templating for reusable Kubernetes manifests
- Set up Helm chart repositories

## Step-by-Step Workflow

### 1. Initialize Chart Structure

```bash
helm create my-app
```

**Standard structure:**
```
my-app/
├── Chart.yaml           # Chart metadata
├── values.yaml          # Default configuration values
├── charts/              # Chart dependencies
├── templates/           # Kubernetes manifest templates
│   ├── NOTES.txt       # Post-install notes
│   ├── _helpers.tpl    # Template helpers
│   ├── deployment.yaml
│   ├── service.yaml
│   └── tests/
└── .helmignore         # Files to ignore
```

### 2. Configure Chart.yaml

Define chart metadata including name, version, dependencies.

See `reference.md` for complete Chart.yaml template.

### 3. Design values.yaml Structure

Organize values hierarchically: image, service, ingress, resources, autoscaling.

See `reference.md` for complete values.yaml structure.

### 4. Create Template Files

Use Go templating with Helm functions for deployments, services, configmaps.

See `reference.md` for deployment template example.

### 5. Create Template Helpers

Define reusable helpers in `templates/_helpers.tpl` for names, labels, selectors.

See `reference.md` for helper templates.

### 6. Manage Dependencies

```bash
helm dependency update
helm dependency build
```

Override dependency values in values.yaml.

### 7. Test and Validate

```bash
# Lint the chart
helm lint my-app/

# Dry-run installation
helm install my-app ./my-app --dry-run --debug

# Template rendering
helm template my-app ./my-app
```

### 8. Package and Distribute

```bash
helm package my-app/
helm repo index .
```

### 9. Multi-Environment Configuration

Use environment-specific values files:
- `values.yaml` (defaults)
- `values-dev.yaml`
- `values-staging.yaml`
- `values-prod.yaml`

```bash
helm install my-app ./my-app -f values-prod.yaml --namespace production
```

### 10. Implement Hooks and Tests

Add lifecycle hooks (pre-install, post-install) and test pods.

See `reference.md` for hook and test examples.

---

## Best Practices

| Practice | Description |
|----------|-------------|
| Semantic versioning | Use for chart and app versions |
| Document values | Comment all values in values.yaml |
| Template helpers | Use for repeated logic |
| Validate before packaging | Run lint and dry-run |
| Pin dependencies | Explicit version numbers |
| Use conditions | For optional resources |
| Follow naming conventions | Lowercase, hyphens |
| Include NOTES.txt | Usage instructions |
| Consistent labels | Use helpers |
| Test in all environments | Before production |

---

## Related Skills

- `k8s-manifest-generator` - For creating base Kubernetes manifests
- `gitops-workflow` - For automated Helm chart deployments

---

## References

See `reference.md` for:
- Complete Chart.yaml template
- Full values.yaml structure
- Template helpers (_helpers.tpl)
- Deployment template example
- Multi-environment configuration
- Hooks and tests templates
- Common patterns
- Troubleshooting guide
