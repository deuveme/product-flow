# Skill Data Access Guide

How downstream skills can access persisted context, assets, and references from earlier workflow steps.

---

## Asset Directory Structure

Every spec branch includes a standard directory layout for all gathered context:

```
specs/$BRANCH_NAME/
├── spec.md                          ← Main specification
├── gathered-context.md              ← Complete reference (READ THIS FIRST)
├── status.json                      ← Workflow state machine
├── plan.md                          ← Feature plan (created in plan phase)
├── tasks.md                         ← Breakdown of work (created in tasks phase)
│
├── images/                          ← All visual assets
│   ├── wireframe-login.png
│   ├── user-flow.svg
│   ├── screenshot-current.jpg
│   └── sources.md                   ← Links to external visual references (Figma, Storybook, etc.)
│
└── docs/                            ← All documentation assets
    ├── requirements.pdf
    ├── api-specification.pdf
    ├── pasted-requirements.txt
    └── sources.md                   ← Links to external doc references (API docs, design docs, etc.)
```

---

## How to Access Context from `start` Phase

### 1. Read the Gathered Context (mandatory)

**Every skill should start by reading this file:**

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/gathered-context.md"
```

This file contains:
- Full feature description (expanded from initial request)
- All visual assets uploaded (with file paths in `images/`)
- All external documentation (with file paths in `docs/`)
- Product clarifications already answered by the PM
- Technical decisions already made before spec writing
- External links to Figma, API docs, design systems, etc.

**Why**: Prevents re-asking questions already answered, ensures all designs and documentation are available in one place.

### 2. Reference Visual Assets in Specs

When writing specs or documentation, reference images as:

```markdown
## User Flow

![Login Wireframe](images/wireframe-login.png)

See [Figma Design](images/sources.md) for interactive mockups.
```

**Asset files are committed to git** — they persist across sessions and are available to the entire team.

### 3. Access External Links

If you need to follow external links (Figma, Storybook, API docs, etc.):

```bash
# View all external visual references
cat "specs/$BRANCH/images/sources.md"

# View all external documentation
cat "specs/$BRANCH/docs/sources.md"
```

Example `images/sources.md`:
```markdown
# External Visual References

- [Figma Design](https://figma.com/file/ABC123/design-system)
- [Design System Storybook](https://storybook.example.com)
- [Component Library](https://lib.example.com)
```

Example `docs/sources.md`:
```markdown
# External Documentation

- [API Specification](https://api.example.com/v1/docs)
- [Backend Architecture](https://confluence.example.com/backend)
- [Requirements Doc](https://docs.google.com/document/d/ABC123)
```

---

## Data Availability by Phase

### After `/product-flow:start`

✅ Available:
- `specs/$BRANCH_NAME/gathered-context.md`
- `specs/$BRANCH_NAME/images/` (all uploaded images)
- `specs/$BRANCH_NAME/docs/` (all uploaded PDFs/documents)
- `specs/$BRANCH_NAME/images/sources.md` (external visual links)
- `specs/$BRANCH_NAME/docs/sources.md` (external doc links)

### After `speckit.specify` (spec writing)

✅ Available (everything above, plus):
- `specs/$BRANCH_NAME/spec.md`
- Quality checklist embedded in spec

### After `speckit.plan` (planning)

✅ Available (everything above, plus):
- `specs/$BRANCH_NAME/plan.md`

### After `speckit.tasks` (task breakdown)

✅ Available (everything above, plus):
- `specs/$BRANCH_NAME/tasks.md`

---

## Code Example: Reading Assets in a Skill

```bash
#!/bin/bash
# Reading assets and context in any skill

BRANCH=$(git branch --show-current)
SPEC_DIR="specs/$BRANCH"

# Read gathered context
echo "=== Checking gathered context ==="
if [ -f "$SPEC_DIR/gathered-context.md" ]; then
  echo "✓ Found gathered context"
  cat "$SPEC_DIR/gathered-context.md"
else
  echo "✗ No gathered context found"
  exit 1
fi

# Check for visual assets
if [ -d "$SPEC_DIR/images" ] && [ "$(ls -A $SPEC_DIR/images)" ]; then
  echo "✓ Visual assets available:"
  ls -1 "$SPEC_DIR/images"
fi

# Check for documentation assets
if [ -d "$SPEC_DIR/docs" ] && [ "$(ls -A $SPEC_DIR/docs)" ]; then
  echo "✓ Documentation available:"
  ls -1 "$SPEC_DIR/docs"
fi

# Read external references
if [ -f "$SPEC_DIR/images/sources.md" ]; then
  echo "=== External Visual References ==="
  cat "$SPEC_DIR/images/sources.md"
fi

if [ -f "$SPEC_DIR/docs/sources.md" ]; then
  echo "=== External Documentation ==="
  cat "$SPEC_DIR/docs/sources.md"
fi
```

---

## For Skill Developers: How to Pass Assets Downstream

When your skill generates new content that depends on gathered assets:

### 1. Read and Acknowledge

```bash
# At the start of your skill, verify assets are present
if [ ! -f "specs/$BRANCH/gathered-context.md" ]; then
  echo "ERROR: gathered-context.md not found"
  exit 1
fi
```

### 2. Reference in Output

When you write specs, plans, or task descriptions, include references:

```markdown
# Implementation Plan

## Visual Reference
See [wireframe](../images/user-flow.svg) in the gathered assets.

## API Reference
Follow the [API specification](../docs/api-spec.pdf) provided.
```

### 3. Create New Assets If Needed

If your skill generates new visual or documentation artifacts:

```bash
# Add to existing asset folders
cp my-diagram.svg "specs/$BRANCH/images/"
cp my-analysis.pdf "specs/$BRANCH/docs/"

# Update sources.md if adding external references
echo "- [New Design](https://figma.com/...)" >> "specs/$BRANCH/images/sources.md"
```

---

## Troubleshooting

**Q: Why can't I find `images/` or `docs/` folders?**

A: They're only created when the user shares assets during `/product-flow:start` step 2. If folders don't exist, the user didn't provide those assets. Check `gathered-context.md` to confirm.

**Q: Can I modify `gathered-context.md`?**

A: No. It's the authoritative record of what the user provided and what was decided before spec writing. Create new files for your own analysis or decisions (e.g., `plan.md`, `tasks.md`).

**Q: How do I reference an image that's not uploaded yet?**

A: Ask the user to upload it via `/product-flow:start` again (if in early phases) or create a placeholder and note it in the spec as "TODO: Add visual reference".

**Q: Can assets be removed or changed?**

A: Only if the user explicitly asks via a follow-up request. Never delete or modify gathered assets — they're part of the feature's history.

---

## Summary

| Phase | What's Available | How to Access |
|-------|------------------|---------------|
| **After start** | Context + Assets | `specs/$BRANCH/gathered-context.md` + `images/` + `docs/` |
| **Spec writing** | ↑ + Spec draft | Add references: `![alt](images/file.png)` |
| **Planning** | ↑ + Spec + Plan | Link assets in plan decisions |
| **Implementation** | ↑ + Spec + Plan + Tasks | Reference docs in code comments and PR |

**Golden rule**: Start every skill by reading `gathered-context.md` to understand what the user provided and what decisions are already made.
