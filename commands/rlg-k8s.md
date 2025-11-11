---
description: Load Kubernetes specialist agent
---

# Kubernetes Agent Dispatcher

Load a specialized Kubernetes agent for cluster management, deployment, and orchestration.

**Available Agents:**
- `architect` - K8s architect for cluster design and platform engineering (agents/kubernetes/k8s-architect.md)
- `helm` - Helm specialist for chart development and templating (agents/kubernetes/helm-specialist.md)
- `gitops` - GitOps engineer for ArgoCD/Flux and progressive delivery (agents/kubernetes/gitops-engineer.md)
- `security` - K8s security for policies, RBAC, and admission control (agents/kubernetes/k8s-security.md)
- `mesh` - Service mesh expert for Istio/Linkerd/Cilium (agents/kubernetes/service-mesh-expert.md)

**Available Skills:**
- `gitops-workflow` - GitOps patterns with ArgoCD/Flux
- `helm-chart-scaffolding` - Helm chart creation templates
- `k8s-manifest-generator` - Kubernetes YAML generation
- `k8s-security-policies` - OPA, Kyverno, network policies

**Usage:**
- `/rlg-k8s architect` - Load K8s architect
- `/rlg-k8s helm` - Load Helm specialist
- `/rlg-k8s security` - Load security specialist
- `/rlg-k8s` - Show available K8s agents

**Parallel Dispatch:**
You can load multiple K8s agents simultaneously for complex tasks:
```
/rlg-k8s architect
/rlg-k8s security
/rlg-k8s gitops
```

If no agent is specified, present the list of available agents and ask the user which one to load.
