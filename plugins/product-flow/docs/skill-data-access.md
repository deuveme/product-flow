# Skill Data Access Guide

Every feature spec folder (`specs/<branch>/`) contains assets and context
persisted by `/product-flow:start-feature` or `/product-flow:start-improvement`. This guide explains how any downstream
skill can access them across sessions.

---

## Feature context

The complete feature context — full description, PM clarifications, visual
asset references, and external doc references — is stored in a single file:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/gathered-context.md"
```

**Always load this file at the start of a skill session.** It is the
authoritative source for:
- The original feature description provided by the PM
- Product clarifications and terminology agreed during `start`
- References to all visual and documentary assets collected

Load it silently as background context. Do not re-ask questions already
answered there.

---

## Visual assets

Images uploaded by the PM (PNG, JPG, SVG, GIF, etc.) are saved here:

```bash
ls "specs/$BRANCH/images/"
```

Reference individual files by path when describing UI expectations or
comparing against designs:

```bash
cat "specs/$BRANCH/images/<filename>"   # or open with Read tool
```

External visual links (Figma, Storybook, design systems) are listed in:

```bash
cat "specs/$BRANCH/images/sources.md"
```

This file only exists if the PM provided external visual links. Check before
reading:

```bash
[ -f "specs/$BRANCH/images/sources.md" ] && cat "specs/$BRANCH/images/sources.md"
```

---

## External documentation

PDFs, API docs, slide decks, and pasted content are stored here:

```bash
ls "specs/$BRANCH/docs/"
```

Files include:
- Uploaded documents: `<descriptive-name>.pdf`, `<descriptive-name>.txt`, etc.
- Pasted content: `pasted-doc-1.txt`, `pasted-doc-2.txt`, etc.

External doc links (Confluence, Google Docs, API references) are listed in:

```bash
cat "specs/$BRANCH/docs/sources.md"
```

This file only exists if the PM provided external doc links. Check before
reading:

```bash
[ -f "specs/$BRANCH/docs/sources.md" ] && cat "specs/$BRANCH/docs/sources.md"
```

---

## Defensive access pattern

Never assume an asset exists. Always check before depending on it:

```bash
BRANCH=$(git branch --show-current)
SPEC_DIR="specs/$BRANCH"

# Context (always present after start)
[ -f "$SPEC_DIR/gathered-context.md" ] && cat "$SPEC_DIR/gathered-context.md"

# Images (present only if PM uploaded or linked visuals)
[ -d "$SPEC_DIR/images" ] && ls "$SPEC_DIR/images/"
[ -f "$SPEC_DIR/images/sources.md" ] && cat "$SPEC_DIR/images/sources.md"

# Docs (present only if PM uploaded, pasted, or linked documents)
[ -d "$SPEC_DIR/docs" ] && ls "$SPEC_DIR/docs/"
[ -f "$SPEC_DIR/docs/sources.md" ] && cat "$SPEC_DIR/docs/sources.md"
```

---

## When to use this guide

Any skill that needs to understand the feature's original intent, reference
visual designs, or consult external documentation should load the relevant
files at the beginning of its execution — especially when starting a new
session where in-memory context from `start` is no longer available.
