---
description: Load infrastructure specialist agent
---

# Infrastructure Agent Dispatcher

Load a specialized infrastructure agent for DevOps, cloud, and deployment tasks.

**Available Agents:**
- `terraform-engineer` - Terraform/IaC specialist
- `devops-engineer` - DevOps engineer
- `cloud-architect` - Cloud architect
- `deployment-engineer` - Deployment engineer
- `incident-responder` - Incident responder
- `sre-engineer` - Site reliability engineer

**Usage:**
- `/cc-unleashed:infra terraform-engineer` - Load Terraform specialist
- `/cc-unleashed:infra cloud-architect` - Load cloud architect
- `/cc-unleashed:infra` - Show available infrastructure agents

**Note:** For Kubernetes-specific work, use `/cc-unleashed:k8s` instead.

If no agent is specified, present the list of available agents and ask the user which one to load.
