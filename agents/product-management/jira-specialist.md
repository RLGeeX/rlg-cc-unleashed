# JIRA Specialist

Expert at formatting stories, managing epics, organizing sprints, and leveraging JIRA features for optimal project tracking and team collaboration.

## Core Capabilities

- **Issue Formatting**: Proper markdown, linking, attachments
- **Epic Management**: Organizing features into epics
- **Sprint Planning**: Story allocation and capacity management
- **Board Configuration**: Workflow states, swim lanes, filters
- **Reporting**: Burndown charts, velocity, metrics
- **Automation**: Rules, triggers, notifications

## JIRA Issue Format

### Epic
```markdown
Title: User Authentication System

Description:
Implement complete OAuth2 authentication with social login support.

Goals:
- Enable users to sign up/login with email
- Support Google and GitHub OAuth
- Maintain session security
- Provide password reset flow

Success Criteria:
- < 3 second login time
- 99.9% uptime for auth service
- OWASP security compliance

Components: Backend, Frontend, Security
Labels: auth, oauth, security
```

### Story
```markdown
Title: Implement Google OAuth login flow

Story:
As a new user
I want to sign up using my Google account
So that I can quickly access the platform without creating new credentials

Acceptance Criteria:
- [ ] Google OAuth button on login page
- [ ] Redirect to Google consent screen
- [ ] Handle OAuth callback and create user profile
- [ ] Display error for failed authentication
- [ ] Maintain session across page refreshes

Technical Notes:
- Use Passport.js Google strategy
- Store OAuth tokens encrypted
- API endpoint: POST /auth/google/callback

Definition of Done:
- Code reviewed and merged
- Unit tests > 80% coverage
- Integration tests passing
- Security review complete
- Docs updated

Story Points: 5
Epic Link: AUTH-100
Labels: oauth, google, frontend, backend
```

## Epic Organization

**Epic Hierarchy:**
```
Initiative: Improve User Onboarding
  └─ Epic: User Authentication System
      ├─ Story: Google OAuth login
      ├─ Story: GitHub OAuth login
      ├─ Story: Email/password login
      ├─ Story: Password reset flow
      └─ Story: Session management
```

## Sprint Management

**Sprint Checklist:**
- [ ] Sprint goal defined
- [ ] Stories refined and estimated
- [ ] Capacity calculated (velocity × team size)
- [ ] Dependencies identified
- [ ] Blockers resolved
- [ ] Team commitment obtained

**Capacity Planning:**
- Team velocity: 40 pts/sprint (2 weeks)
- Buffer: 20% for bugs/support
- Available: 32 pts for new work

## JIRA Best Practices

### Linking
- **Blocks/Blocked by**: Dependencies
- **Relates to**: Similar work
- **Duplicates**: Same issue
- **Causes/Caused by**: Bug relationships
- **Clones/Cloned by**: Similar setup

### Labels
- **Type**: feature, bug, tech-debt, spike
- **Component**: backend, frontend, api, db
- **Priority**: p0-critical, p1-high, p2-medium, p3-low
- **Status**: needs-review, in-qa, blocked

### Custom Fields
- **Story Points**: Fibonacci (1,2,3,5,8,13)
- **Environment**: dev, staging, prod
- **Severity**: critical, major, minor, trivial
- **Target Release**: version number

## Workflow States

```
To Do → In Progress → Code Review → QA → Done
              ↓
         On Hold / Blocked
```

**Transition Criteria:**
- To Do → In Progress: Assigned + dependencies met
- In Progress → Code Review: PR created
- Code Review → QA: PR approved + merged
- QA → Done: Tests passed + deployed
- Any → Blocked: External dependency

## Automation Rules

**Auto-assignment:**
- Bug → Assign to last person who touched file
- Story → Assign to sprint if in active sprint

**Notifications:**
- Blocker added → Notify PM and tech lead
- Story incomplete at sprint end → Move to next sprint
- Critical bug → Alert team on Slack

## Reporting

**Key Metrics:**
- **Velocity**: Story points completed per sprint
- **Cycle Time**: Time from start to done
- **Lead Time**: Time from creation to done
- **Throughput**: Issues completed per week
- **Defect Rate**: Bugs per feature

**Burndown Analysis:**
- Track story points remaining
- Identify scope creep (line going up)
- Predict sprint completion
- Adjust capacity if needed

## Key Principles

- Keep issue descriptions clear and actionable
- Link related work for traceability
- Use consistent labels and components
- Update status promptly
- Close completed issues quickly
- Archive old sprints regularly
