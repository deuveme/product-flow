---
name: bdd-with-approvals
description: Scannable BDD tests written in domain language. Use when doing BDD.
---
icon: 📋

# BDD with Approval Tests

## The Problem

Specifications live in documents. They drift from reality because nothing enforces them.

Tests verify implementation. Written after code, they document what IS, not what SHOULD BE. They're noisy. You can't glance at them and quickly validate correctness.

You need an artifact that:
- Captures expected behavior before code exists
- Stays in sync because it's executable
- A human can validate at a glance

## Executable Specifications

The fixture file IS that artifact. Write it BEFORE implementation.

Think through scenarios by creating approval files. Describe expected behavior in domain language. Implementation is driven by making these specs pass. Specs stay executable, never go stale.

A human looks at the fixture and immediately sees: correct or not. No translation between "spec" and "test". They're the same artifact.

## Approved Fixtures

Approval files containing expected output in a format designed for human validation. Input lives in test code. Vitest compares actual output against the approved file.

Every fixture follows the same structure:

```
## Scenario
{what situation we're in}

## {Input section — what triggers the behavior}
{details}

## {Output section — what the user/system sees}
{details}
```

**Backend example** (API endpoint):

```
## Scenario
User places order with valid payment

## Request
POST /orders {"product_id": "laptop-123", "quantity": 1}

## External Calls
POST /inventory/reserve → 200 {"reservation_id": "res_789"}
POST /payment/process → 200 {"transaction_id": "txn_abc"}

## Response
Status: 200
Order: confirmed
Total: $1000
```

**Frontend example** (React component):

```
## Scenario
API responds but DB is down

## API Call
GET /api/health → 200 {"status": "ok", "db": "error"}

## Screen
API: ok (green)
DB: error (red)
```

Test code provides input, formatter captures output, `toMatchFileSnapshot()` handles comparison. Adding test cases = adding tests with new inputs, not assertion code.

**The format question:** Can someone validate correctness in <5 seconds?

Design for human eyes, not machine parsing. Columnar layouts, consistent structure, whitespace that groups related elements. Avoid dense JSON, single-line formats, anything requiring mental parsing.

**One-time setup:**
1. Formatter (printer) - converts actual output to fixture format
2. Test doubles - fakes that record interactions for the formatter to consume

## Vitest Integration

Use `toMatchFileSnapshot()`. No external libraries.

```typescript
await expect(output).toMatchFileSnapshot(
  "./fixtures/{spec-name}/{scenario}.approved.txt"
);
```

First run: file doesn't exist, Vitest creates it with actual output. You review. Correct? Commit. Wrong? Fix code, rerun.

Subsequent runs: compares against approved file. Diff = failure. Intentional change? `vitest -u` updates approved files.

## Fixture Organization

One subfolder per spec file inside `fixtures/`:

```
specs/
  health-dashboard.spec.tsx
  order-processing.spec.ts
  fixtures/
    health-dashboard/
      loading.approved.txt
      healthy-system.approved.txt
      db-down.approved.txt
    order-processing/
      valid-order.approved.txt
      payment-declined.approved.txt
```

## Formatters

The formatter assembles captured data into scannable output. Build one per spec — it defines what the fixture looks like.

**Backend formatter** (use case with HTTP response and side effects):

```typescript
type ExternalCall = { method: string; url: string; result: string };

function formatFixture(
  scenario: string,
  request: { method: string; url: string; body?: string },
  response: { status: number; body: any },
  externalCalls: ExternalCall[],
): string {
  const sections = [
    `## Scenario`,
    scenario,
    ``,
    `## Request`,
    `${request.method} ${request.url}${request.body ? ` ${request.body}` : ""}`,
  ];

  if (externalCalls.length > 0) {
    sections.push(
      ``,
      `## External Calls`,
      ...externalCalls.map((c) => `${c.method} ${c.url} → ${c.result}`),
    );
  }

  sections.push(``, `## Response`, `Status: ${response.status}`, JSON.stringify(response.body, null, 2));

  return sections.join("\n");
}
```

**Frontend formatter** (React component with API interactions):

```typescript
type ApiCall = { method: string; url: string; result: string };

function formatScreen(): string {
  return screen
    .getAllByRole("paragraph")
    .map((p) => {
      const color = (p as HTMLElement).style.color || "default";
      return `${p.textContent} (${color})`;
    })
    .join("\n");
}

function formatFixture(scenario: string, apiCall?: ApiCall): string {
  const sections = [`## Scenario`, scenario, ``];

  if (apiCall) {
    sections.push(`## API Call`, `${apiCall.method} ${apiCall.url} → ${apiCall.result}`, ``);
  }

  sections.push(`## Screen`, formatScreen());

  return sections.join("\n");
}
```

## Capturing Side Effects

Fixtures don't generate themselves. Capture data through test doubles and dependency injection.

Define the interface, build a fake that records interactions:

```typescript
interface PaymentGateway {
  charge(amount: number, token: string): Promise<{ transactionId: string }>;
}

function createFakePaymentGateway() {
  const calls: ExternalCall[] = [];
  return {
    calls,
    gateway: {
      charge: async (amount, token) => {
        const result = { transactionId: "txn_abc" };
        calls.push({
          method: "POST",
          url: "/payment/charge",
          result: `200 ${JSON.stringify(result)}`,
        });
        return result;
      },
    } satisfies PaymentGateway,
  };
}
```

Production code depends on the interface. Tests inject the fake. Recorded `calls` feed the formatter.

## Full Examples

**Backend spec:**

```typescript
it("processes valid order", async () => {
  const { calls, gateway } = createFakePaymentGateway();
  const useCase = new PlaceOrder(gateway);

  const response = await useCase.execute({ productId: "laptop-123", quantity: 1 });

  const output = formatFixture(
    "User places order with valid payment",
    { method: "POST", url: "/orders", body: '{"product_id": "laptop-123"}' },
    { status: 200, body: response },
    calls,
  );

  await expect(output).toMatchFileSnapshot(
    "./fixtures/order-processing/valid-order.approved.txt",
  );
});
```

**Frontend spec:**

```typescript
it("shows DB error when API responds but DB is down", async () => {
  vi.spyOn(globalThis, "fetch").mockResolvedValue(
    new Response(JSON.stringify({ status: "ok", db: "error" })),
  );

  render(<HealthDashboard />);

  await waitFor(() => {
    expect(screen.getByText("DB: error")).toBeInTheDocument();
  });

  const output = formatFixture("API responds but DB is down", {
    method: "GET",
    url: "/api/health",
    result: '200 {"status": "ok", "db": "error"}',
  });

  await expect(output).toMatchFileSnapshot(
    "./fixtures/health-dashboard/db-down.approved.txt",
  );
});
```

Everything in the fixture comes from what you inject and capture. The approval mechanism only handles comparison. How dependencies are wired is an architecture decision, not part of this pattern.
