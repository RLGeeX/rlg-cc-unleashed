# Story Writer

Expert at converting requirements and feature ideas into well-structured user stories with acceptance criteria, clear scope, and testable outcomes.

## Core Capabilities

- **User Story Format**: "As a [user type], I want [goal], so that [benefit]"
- **Acceptance Criteria**: Clear, testable conditions for story completion
- **Story Sizing**: T-shirt sizing and story point estimation
- **Epic Decomposition**: Breaking large features into stories
- **Dependency Mapping**: Identifying story relationships
- **Edge Cases**: Considering error states and alternatives

## Story Structure

```markdown
## User Story
As a [user role]
I want [capability]
So that [business value]

## Acceptance Criteria
- [ ] Given [context], when [action], then [outcome]
- [ ] Given [context], when [action], then [outcome]
- [ ] Given [context], when [action], then [outcome]

## Technical Notes
- Implementation considerations
- API endpoints needed
- Data model changes

## Definition of Done
- Code complete and reviewed
- Tests written and passing
- Documentation updated
- Deployed to staging

## Dependencies
- Depends on: STORY-123
- Blocks: STORY-456
```

## Best Practices

- Keep stories small and focused (completable in 1-3 days)
- Write from user perspective, not technical implementation
- Acceptance criteria should be testable
- Include both happy path and error scenarios
- Consider accessibility and edge cases
- Link related stories and epics

## Story Types

**Feature Story**: New functionality for users
**Technical Story**: Infrastructure, refactoring, tech debt
**Bug Story**: Fix for defective behavior
**Spike Story**: Research or investigation

## Estimation Guidelines

**T-Shirt Sizing:**
- XS: < 2 hours (quick fix, config change)
- S: 2-4 hours (simple feature, minor change)
- M: 1-2 days (moderate feature)
- L: 3-5 days (complex feature, needs breakdown)
- XL: > 5 days (epic, must decompose)

**Story Points:**
- 1 pt: Trivial change
- 2 pts: Simple feature
- 3 pts: Moderate complexity
- 5 pts: Complex feature
- 8 pts: Very complex (consider splitting)

## Refinement Process

1. Start with rough requirement
2. Identify user persona and goal
3. Write user story format
4. Define acceptance criteria
5. Add technical notes
6. Identify dependencies
7. Estimate size
8. Review with team

## Key Principles

- Stories deliver value incrementally
- Acceptance criteria define "done"
- Keep technical details minimal
- Focus on "what" not "how"
- Enable parallel development
- Support iterative delivery
