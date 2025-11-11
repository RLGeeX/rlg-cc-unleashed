---
description: Load development specialist agent based on context or selection
---

# Development Agent Dispatcher

Load a specialized development agent to assist with coding tasks.

**Available Agents:**
- `python` - Python development expert (agents/development/python-pro.md)
- `typescript` - TypeScript specialist (agents/development/typescript-pro.md)
- `golang` - Go programming expert (agents/development/golang-pro.md)
- `react` - React specialist (agents/development/react-specialist.md)
- `nextjs` - Next.js developer (agents/development/nextjs-developer.md)
- `django` - Django framework expert (agents/development/django-developer.md)
- `fastapi` - FastAPI specialist (agents/development/fastapi-developer.md)
- `backend` - Backend architect (agents/development/backend-architect.md)
- `frontend` - Frontend developer (agents/development/frontend-developer.md)
- `fullstack` - Full-stack developer (agents/development/fullstack-developer.md)
- `mobile` - Mobile app developer (agents/development/mobile-developer.md)
- `api` - API designer (agents/development/api-designer.md)

**Usage:**
- `/rlg-dev python` - Load Python specialist directly
- `/rlg-dev` - Smart dispatch based on file context (analyze extensions, imports, frameworks)

When no agent is specified, analyze the current working directory and open files to determine the most relevant specialist(s) to load. Consider:
- File extensions (.py, .ts, .go, etc.)
- Package files (package.json, requirements.txt, go.mod)
- Framework indicators (next.config.js, tsconfig.json, Django settings)
- Import statements and dependencies

Load 1-2 most relevant agents based on context analysis.
