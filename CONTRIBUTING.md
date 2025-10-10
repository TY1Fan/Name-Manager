# Contributing Guide

## Branching Strategy

We use a **feature branch workflow** with protected main branch.

| Branch | Purpose |
|--------|----------|
| `main` | Production-ready code. |
| `dev` | Development branch; all features are merged here before release. |
| `feature/*` | New features are coded here.  Please open an issue before implementing new features. |
| `fix/*` | Bug fixes. Please open an issue before fixing the bugs. |
| `plan/*` | Documentation or spec updates. |

### Example
```
git checkout -b feature/add-test
```

## Commit Style

### Subject Line Convention

- Every commit must have a concise (less than 50 characters) and precise subject line.

- Use imperative mood and capitalize the first letter of the subject line.

- Do not end the subject line with a full-stop.

- You may add a <scope>: or <category>: in front, when applicable.

```
e.g. 
Person class: Remove static imports
Main.java: Remove blank lines
bug fix: Add space after name
chore: Update release date
```

### Body Convention

- Commit messages for non-trivial commits should have a body giving details of the commit.

- Structure the body as follows:

```
{current situation} -- use present tense

{why it needs to change}

{what is being done about it} -- use imperative mood

{why it is done that way}

{any other relevant info}
```

## Code Review Checklist

For Contributors:

- All tests pass locally (npm test, pytest, etc.)

- Code style and lint checks pass

- Added or updated relevant unit/integration tests

- Updated docs/specs

For Reviewers:

- Readability and maintainability

- Function and variable naming clarity

- Performance, security, and correctness

- Test coverage for new functionality

- Alignment with project goals and specs
