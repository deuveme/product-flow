---
name: backend-architecture
description: "DDD with hexagonal architecture for backend structure."
user-invocable: false
---
icon: 🏗️

# Hexagonal Architecture

## Boundary Rule

Something belongs inside the hexagon if it has no infrastructure dependencies — direct or transitive.

**Inside** (domain or application):
- Business rules, entities, value objects
- Use cases, application services
- Ports — interfaces that define how the hexagon talks to the outside
- Pure logic, no I/O

**Outside** (adapters):
- Web frameworks, HTTP handlers
- Database drivers, repositories
- External API clients
- File system, queues, caches

## Layers

```
                    ┌──────────────────────┐
                    │      Adapters        │
                    │  (implement ports)   │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │     Application      │
                    │   (orchestration)    │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │       Domain         │
                    │   (defines ports)    │
                    └──────────────────────┘

              Dependencies flow INWARD (down)
```

## Naming

- Domain entity: `Member`
- Value object: `Email`
- Incoming DTO: `*Request` → `CreateMemberRequest`
- Outgoing DTO: `*Response` → `MemberResponse`
- DTO → Domain: `as*()` method → `request.asMember()` → `Member`
- Domain → DTO: `static from(domain)` → `MemberResponse.from(member)`
- Port → Adapter: `MemberRepository` → `SqlMemberRepository`

## Anti-Patterns

- **Brittle interfaces** — Functions with many parameters break when requirements change. Use wrapper objects.
- **Domain scope pollution** — Third-party types leaking into domain. Map to domain types at the boundary. Never expose SDK types through ports — ports speak domain language only.
- **Use-case interdependencies** — Use cases calling other use cases. Each use case orchestrates domain objects directly, self-contained.
- **Anemic domain** — Entities as data bags with logic in services. Business rules belong IN entities and value objects.
- **Premature database design** — Schema before domain model. Domain model comes first; adapter maps to it.
- **Over-complicated adapters** — Adapters adding logic beyond translation. Keep them thin — just implement the port interface. Specific smells:
  - *Generic wrappers* — Wrapping an entire SDK "just in case". Expose only what you use today.
  - *Pass-through methods* — Adapter methods that just forward to SDK with same signature. Translate to domain language instead.
  - *Leaking SDK types* — Returning or accepting SDK-specific types (e.g., `AWS.S3.GetObjectOutput`). Map to domain types at the adapter boundary.

## Adapter Design

**Rule**: Expose only what you use today, in your domain's language.

**Single-class** — When the SDK is simple (1-3 methods, minimal config). The adapter implements the port and calls the SDK directly.

**Two-layer (client + adapter)** — When the SDK is complex, needs shared config, or serves multiple adapters:
- *Client*: Thin wrapper over the SDK. Handles config, credentials, and SDK-specific translation. Exposes simple methods.
- *Adapter*: Implements the port using the client. Translates between domain language and client methods.

Use two-layer when: the SDK requires configuration (credentials, regions, connection pools) that would be duplicated across adapters, or when multiple adapters share the same underlying SDK client.

## File Structure

```
src/
  components/
    <bounded-context>/
      __tests__/
        <entry-point>/
          index.spec.ts                             # integration test (handler → use case)
          fixtures/                                 # .approved.txt approval snapshots
      domain/
        entity/
          subscription.ts                           # entity
        valueObject/
          subscriptionProduct.ts                    # value object
        repository/
          subscriptionRepository.ts                 # port (interface)
        service/
          subscriptionFinder.ts                     # domain service (interface)
        event/
          subscriptionCreatedDomainEvent.ts         # domain event
        error/
          subscriptionNotFound.ts                   # domain error
        definition/
          subscriptionStatus.ts                     # types, const maps
        mapper/
          subscriptionMapper.ts                     # domain mapper
        strategy/
          subscriptionActiveStrategy.ts             # domain strategy
      application/
        <action>/
          <action>UseCase.ts                        # use case (extends UseCase<Req, Res>)
          <action>UseCase.spec.ts                   # unit test
          <action>Request.ts                        # incoming DTO (type alias)
        mapper/
          subscriptionResponseMapper.ts             # response mapper (static .map())
        response/
          subscriptionResponse.ts                   # outgoing DTO (type alias)
        event/
          paymentOrderedIntegrationEvent.ts         # integration event
      infrastructure/
        controller/
          http/<verb>/
            <action>GetController.ts                # HTTP controller (API Gateway)
            <action>GetHandler.ts                   # Lambda handler export
          lambda/<action>/
            <action>InvokeController.ts             # Lambda-to-Lambda controller
            <action>InvokeHandler.ts                # Lambda handler export
          sns/
            on<Event>SnsController.ts               # SNS event controller
            on<Event>SnsHandler.ts                  # Lambda handler export
          webhook/
            <context>WebhookControllerStripe.ts     # Stripe webhook controller
        persistence/
          dynamodb/
            <entity>RepositoryDynamoDb.ts           # implements port (@injectable)
          s3/
            <entity>RepositoryS3.ts                 # implements port (extends S3Repository)
        service/
          stripe/
            <entity>ServiceStripe.ts                # external service adapter
          network/
            <entity>NetworkService.ts               # inter-service Lambda invoke adapter
        validator/
          <action>RequestValidator.ts               # request validation (extends ValidatorJoi)
        mapper/
          <entity>DynamoDbMapper.ts                 # infra ↔ domain mapping
        definition/
          dto/
            <entity>DbDto.ts                        # persistence DTO
  shared/
    domain/
      entity/ valueObject/ repository/ service/ event/ error/ definition/
    application/
      useCases/ mapper/ event/
    infrastructure/
      clients/ controller/ persistence/ services/ validators/
  config/
    di/
      module/
        <bounded-context>.ts                        # Inversify ContainerModule per context
      shared/
        index.ts                                    # shared DI bindings
    environment.ts                                  # stage guards (isDev, isProd, ...)
```

## Implementation Order

Build from the inside out — domain first, infrastructure last, integration at the end:

```
ports → use case + tests (with fakes) → adapters + tests → integration (tool registration, wiring)
```

Each layer builds on the previous one. No layer depends on something that hasn't been built yet.

## Testing

- **Domain**: Unit tests, no doubles needed (pure logic)
- **Application**: Unit tests with port doubles (fake repositories, stub notifiers)
- **Adapters**: Integration tests with isolated infrastructure (containers for databases, HTTP mocks for external APIs)

Ports give clean seams for test doubles. Test domain exhaustively with fast unit tests. Test adapters with controlled infrastructure.
