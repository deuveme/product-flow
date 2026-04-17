---
description: "Feature-based architecture for React frontends."
user-invocable: false
icon: 🧩
model: haiku
context: fork
effort: low
---

# Frontend Architecture (Feature-Based)

## Core Principle

Something belongs inside a feature if it's only used by that feature. When a second feature needs it, promote to shared.

## Organizational Structure

**Inside features**: Feature-specific components and hooks managing state/logic

**Shared resources**: UI primitives, multi-feature hooks, utilities, and API clients

## Directory Layout

```
src/pages/ → HealthDashboard.tsx
src/features/health/ → components/, hooks/, index.ts
src/components/ → shared UI elements
src/hooks/ → shared hooks
src/lib/ → utilities and API client
```

## Naming Conventions

- Pages: `HealthDashboard.tsx` (PascalCase, descriptive)
- Feature folders: lowercase nouns (`health`, `settings`)
- Components: `HealthStatus.tsx` (PascalCase)
- Hooks: `useHealthStatus.ts` (camelCase with `use` prefix)

## Key Practices

**Colocation**: Begin with inline code and extract only when multiple consumers appear.

**Separation**: Pages compose features without business logic; hooks manage side effects; components render UI exclusively.

**Anti-patterns to avoid**: Fat components, cross-feature imports, excessive prop drilling.

**Build sequence**: Hook → Component → Page → App integration.
