# Sample Council Prompts

Effective prompts for Multi-Model Council. Copy and adapt for your use cases.

---

## 1. Architecture Review

```
/council We're designing a notification service that needs to handle 10K events/sec
with at-least-once delivery. Should we use Kafka, RabbitMQ, or AWS SQS?
Consider: throughput, ordering guarantees, operational complexity, and cost.
```

**Why this works**: Gives concrete requirements (throughput, delivery semantics) so each model can reason about trade-offs rather than giving generic advice.

---

## 2. Code Review / Debugging Strategy

```
/council Review this function for correctness and performance issues:

async function batchProcess(items: Item[], batchSize = 100) {
  const results = [];
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const batchResults = await Promise.all(
      batch.map(item => processItem(item))
    );
    results.push(...batchResults);
  }
  return results;
}

Focus on: error handling, memory usage with large arrays, and concurrency control.
```

**Why this works**: Includes the actual code inline and directs attention to specific concerns. Each model will catch different issues.

---

## 3. Technology Comparison

```
/council Compare Vite, Turbopack, and Rspack for a large React 19 monorepo
(~200 packages, ~500K LOC TypeScript). We need fast dev server startup,
reliable HMR, and good CI build times. Team currently uses Webpack 5.
```

**Why this works**: Specifies the exact scale, tech stack, and current baseline so models can give actionable comparisons instead of generic feature lists.

---

## 4. Database Schema Design

```
/council We need to model a multi-tenant SaaS permission system.
Requirements:
- Tenants have organizations, organizations have teams
- RBAC with custom roles per organization
- Row-level security in PostgreSQL
- Need to support 1000+ tenants, ~50K users total

Should we use: (a) shared schema with tenant_id column,
(b) schema-per-tenant, or (c) database-per-tenant?
Also suggest the permission table design.
```

**Why this works**: Provides concrete scale numbers and explicit design options. Models will analyze trade-offs from different angles (performance, isolation, operational cost).

---

## 5. Migration Strategy

```
/council Our Python backend (Django 4.2, 80K LOC) needs to migrate from
REST to GraphQL for our mobile clients. We're considering:
1. Big-bang rewrite with Strawberry GraphQL
2. Incremental adoption with graphene-django alongside existing REST
3. API gateway (Apollo Federation) wrapping existing REST endpoints

Team: 5 backend devs, 3 mobile devs. Timeline: 6 months.
What's the safest approach?
```

**Why this works**: Presents specific options with team context and timeline constraints. Each model will weigh risk/reward differently, producing genuinely useful divergence.

---

## Tips for Effective Council Prompts

1. **Be specific about constraints** — team size, timeline, scale, existing tech stack
2. **Include code or schemas** when asking about technical details
3. **Name concrete options** when you have candidates — models reason better about trade-offs than open-ended "what should we use?"
4. **Specify evaluation criteria** — "consider cost, latency, and operational complexity" focuses the analysis
5. **Provide context about current state** — "we currently use X" helps models assess migration effort
