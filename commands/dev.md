---
description: Load development specialist agent based on context or selection
---

# Development Agent Dispatcher

Load a specialized development agent to assist with coding tasks.

**Available Agents:**
- `python-pro` - Python development expert
- `typescript-pro` - TypeScript specialist
- `golang-pro` - Go programming expert
- `react-specialist` - React specialist
- `nextjs-developer` - Next.js developer
- `django-developer` - Django framework expert
- `fastapi-developer` - FastAPI specialist
- `backend-architect` - Backend architect
- `frontend-developer` - Frontend developer
- `fullstack-developer` - Full-stack developer
- `mobile-developer` - Mobile app developer
- `api-designer` - API designer

**Usage:**
- `/cc-unleashed:dev python-pro` - Load Python specialist directly
- `/cc-unleashed:dev` - Smart dispatch based on file context (analyze extensions, imports, frameworks)

When no agent is specified, analyze the current working directory and open files to determine the most relevant specialist(s) to load. Consider:
- File extensions (.py, .ts, .go, etc.)
- Package files (package.json, requirements.txt, go.mod)
- Framework indicators (next.config.js, tsconfig.json, Django settings)
- Import statements and dependencies

Load 1-2 most relevant agents based on context analysis.
