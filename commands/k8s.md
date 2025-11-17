---
description: Load Kubernetes specialist agent
---

# Kubernetes Agent Dispatcher

Load a specialized Kubernetes agent for cluster management, deployment, and orchestration.

**Available Agents:**
- `k8s-architect` - K8s architect for cluster design and platform engineering
- `helm-specialist` - Helm specialist for chart development and templating
- `gitops-engineer` - GitOps engineer for ArgoCD/Flux and progressive delivery
- `k8s-security` - K8s security for policies, RBAC, and admission control
- `service-mesh-expert` - Service mesh expert for Istio/Linkerd/Cilium

**Available Skills:**
- `gitops-workflow` - GitOps patterns with ArgoCD/Flux
- `helm-chart-scaffolding` - Helm chart creation templates
- `k8s-manifest-generator` - Kubernetes YAML generation
- `k8s-security-policies` - OPA, Kyverno, network policies

**Usage:**
- `/cc-unleashed:k8s k8s-architect` - Load K8s architect
- `/cc-unleashed:k8s helm-specialist` - Load Helm specialist
- `/cc-unleashed:k8s k8s-security` - Load security specialist
- `/cc-unleashed:k8s` - Show available K8s agents

**Parallel Dispatch:**
You can load multiple K8s agents simultaneously for complex tasks:
```
/cc-unleashed:k8s k8s-architect
/cc-unleashed:k8s k8s-security
/cc-unleashed:k8s gitops-engineer
```

If no agent is specified, present the list of available agents and ask the user which one to load.
