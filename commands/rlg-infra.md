---
description: Load infrastructure specialist agent
---

# Infrastructure Agent Dispatcher

Load a specialized infrastructure agent for DevOps, cloud, and deployment tasks.

**Available Agents:**
- `terraform` - Terraform/IaC specialist (agents/infrastructure/terraform-engineer.md)
- `devops` - DevOps engineer (agents/infrastructure/devops-engineer.md)
- `cloud` - Cloud architect (agents/infrastructure/cloud-architect.md)
- `deploy` - Deployment engineer (agents/infrastructure/deployment-engineer.md)
- `incident` - Incident responder (agents/infrastructure/incident-responder.md)
- `sre` - Site reliability engineer (agents/infrastructure/sre-engineer.md)

**Usage:**
- `/rlg-infra terraform` - Load Terraform specialist
- `/rlg-infra cloud` - Load cloud architect
- `/rlg-infra` - Show available infrastructure agents

**Note:** For Kubernetes-specific work, use `/rlg-k8s` instead.

If no agent is specified, present the list of available agents and ask the user which one to load.
