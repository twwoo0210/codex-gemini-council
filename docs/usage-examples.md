# Usage Examples

This document shows real-world scenarios where the Multi-Model Council adds value by combining perspectives from Claude Opus 4.6, GPT-5.3-Codex, and Gemini 3.1 Pro.

## Example 1: Architecture Review

### Input

```bash
bash .claude/bin/ask-council.sh "Review this architecture: A React SPA talks to a FastAPI backend. The backend uses SQLAlchemy with PostgreSQL. We're considering adding Redis for caching and Celery for background tasks. Current scale is 10K DAU, projected to reach 100K in 6 months. What are the risks and what would you change?" 180
```

### Expected Output Format

> **Note**: The current session acts as a **pure synthesizer**. It does not form its own opinion — instead, Claude's independent opinion comes from a separate, context-isolated session via `ask-claude.sh`.

```markdown
## Council Synthesis (Claude Opus 4.6 + GPT-5.3 + Gemini 3.1 Pro)

### Consensus
- Redis caching is appropriate for this scale trajectory
- Celery + Redis as broker is a well-established pattern
- Connection pooling should be configured before scaling

### Divergence
- **Claude**: Recommends evaluating whether Celery is needed yet — simpler
  background task solutions (e.g., FastAPI BackgroundTasks) may suffice at 10K DAU
- **GPT-5.3**: Emphasizes adding read replicas for PostgreSQL early
- **Gemini**: Suggests considering Cloud Tasks / Pub-Sub instead of self-managed Celery

### Recommendation
Add Redis now for caching. Defer Celery until background task complexity
justifies it. Configure PgBouncer for connection pooling immediately.

---
<details><summary>Claude Opus 4.6 Raw Response</summary>
[full response from isolated Claude session]
</details>

<details><summary>GPT-5.3-Codex Raw Response</summary>
[full response]
</details>

<details><summary>Gemini 3.1 Pro Raw Response</summary>
[full response]
</details>
```

## Example 2: Code Review / Debugging Strategy

### Input

```bash
bash .claude/bin/ask-council.sh "We have a memory leak in a Node.js Express server. RSS grows by ~50MB/hour under load. The app uses Prisma ORM, Bull queues, and Socket.IO. What is the most likely cause and what is the systematic debugging approach?" 180
```

### Expected Output Format

```markdown
## Council Synthesis (Claude Opus 4.6 + GPT-5.3 + Gemini 3.1 Pro)

### Consensus
- Socket.IO event listener accumulation is the most common cause
- Bull queue job references can prevent garbage collection
- Heap snapshots with --inspect are the correct diagnostic tool

### Divergence
- **Claude**: Prioritizes Socket.IO disconnect handler audit
- **GPT-5.3**: Points to Prisma connection pool exhaustion as equally likely
- **Gemini**: Recommends clinic.js as the first diagnostic step

### Recommendation
1. Take heap snapshots at 0, 30, 60 min with `--inspect`
2. Compare retained objects — look for Socket.IO listeners and Bull job refs
3. Audit disconnect handlers for proper cleanup
4. Check Prisma connection pool settings (pool size, timeout)

---
<details><summary>Claude Opus 4.6 Raw Response</summary>
[full response from isolated Claude session]
</details>

<details><summary>GPT-5.3-Codex Raw Response</summary>
[full response]
</details>

<details><summary>Gemini 3.1 Pro Raw Response</summary>
[full response]
</details>
```

## Example 3: Technology Comparison

### Input

```bash
bash .claude/bin/ask-council.sh "Compare Redis vs Memcached for a session store serving 50K concurrent users. Requirements: sub-5ms p99 latency, HA with automatic failover, minimal ops overhead. We run on AWS." 180
```

### Expected Output Format

```markdown
## Council Synthesis (Claude Opus 4.6 + GPT-5.3 + Gemini 3.1 Pro)

### Consensus
- Redis is the better choice for this use case
- ElastiCache Redis with Multi-AZ provides the required HA
- Both can meet sub-5ms p99 at this scale

### Divergence
- **Claude**: Notes Memcached's multi-threaded architecture gives better
  per-node throughput, but Redis Cluster compensates with horizontal scaling
- **GPT-5.3**: Recommends Redis 7+ with ACLs for security at scale
- **Gemini**: Suggests evaluating DynamoDB DAX as a fully managed alternative

### Recommendation
Use ElastiCache Redis (cluster mode enabled) with Multi-AZ. Redis provides
richer data structures, built-in persistence, and Lua scripting — all useful
beyond basic session storage. The ops overhead difference is negligible on
ElastiCache.

---
<details><summary>Claude Opus 4.6 Raw Response</summary>
[full response from isolated Claude session]
</details>

<details><summary>GPT-5.3-Codex Raw Response</summary>
[full response]
</details>

<details><summary>Gemini 3.1 Pro Raw Response</summary>
[full response]
</details>
```

## Example 4: Document Draft Review

### Input

```bash
bash .claude/bin/ask-council.sh "Review this API design doc summary: We plan to expose a REST API for invoice management. Endpoints: POST /invoices, GET /invoices/:id, PATCH /invoices/:id, DELETE /invoices/:id. Auth via JWT. Rate limit 100 req/min per user. All monetary values as integers (cents). What is missing or could be improved?" 180
```

### Expected Output Format

```markdown
## Council Synthesis (Claude Opus 4.6 + GPT-5.3 + Gemini 3.1 Pro)

### Consensus
- Missing: LIST endpoint (GET /invoices with pagination)
- Missing: Idempotency key for POST to prevent duplicate invoices
- Currency field is required alongside cent-based amounts

### Divergence
- **Claude**: Recommends adding bulk operations (POST /invoices/batch)
- **GPT-5.3**: Suggests versioning the API from day one (/v1/invoices)
- **Gemini**: Recommends webhook support for invoice state changes

### Recommendation
Add GET /invoices with cursor pagination, require Idempotency-Key header
on POST, include a currency ISO code field, and version the API as /v1/.

---
<details><summary>Claude Opus 4.6 Raw Response</summary>
[full response from isolated Claude session]
</details>

<details><summary>GPT-5.3-Codex Raw Response</summary>
[full response]
</details>

<details><summary>Gemini 3.1 Pro Raw Response</summary>
[full response]
</details>
```

## Example 5: Complex Problem Solving

### Input

```bash
bash .claude/bin/ask-council.sh "We need to migrate a 2TB PostgreSQL database from on-premise to AWS RDS with less than 1 hour of downtime. The database has 500+ tables, heavy foreign key constraints, and receives ~5000 writes/sec during business hours. What migration strategy do you recommend?" 180
```

### Expected Output Format

```markdown
## Council Synthesis (Claude Opus 4.6 + GPT-5.3 + Gemini 3.1 Pro)

### Consensus
- AWS DMS (Database Migration Service) with CDC (Change Data Capture) is
  the standard approach
- Full load + CDC replication minimizes downtime
- Foreign key constraints should be disabled during initial load

### Divergence
- **Claude**: Recommends pglogical for native PostgreSQL logical replication
  as a DMS alternative, noting better handling of complex constraints
- **GPT-5.3**: Suggests a two-phase approach: DMS for bulk + custom
  pg_dump/restore for edge cases DMS handles poorly
- **Gemini**: Recommends using AWS SCT (Schema Conversion Tool) first to
  identify incompatibilities, even for homogeneous migration

### Recommendation
1. Use AWS DMS with CDC for continuous replication
2. Disable FK constraints and triggers on target during full load
3. Run parallel validation with pg_verify_checksums
4. Schedule cutover during lowest-traffic window
5. Target: 15-30 min actual downtime for DNS switch + final sync

---
<details><summary>Claude Opus 4.6 Raw Response</summary>
[full response from isolated Claude session]
</details>

<details><summary>GPT-5.3-Codex Raw Response</summary>
[full response]
</details>

<details><summary>Gemini 3.1 Pro Raw Response</summary>
[full response]
</details>
```

## Example 6: Team Deliberation Mode (`COUNCIL_MODE=team`)

Team 모드에서는 각 모델이 4단계 심의를 거쳐 더 깊은 분석을 제공합니다.

### Input

```bash
# Team 모드 (기본값)
bash scripts/ask-council.sh "Should we use a monorepo or polyrepo for a microservices architecture with 5 services and a shared component library?" 180
```

### Expected Output Format (Team Mode)

Each model's raw response contains all 4 phases:

```markdown
## Council Synthesis (Claude Opus 4.6 + GPT-5.3 + Gemini 3.1 Pro)

### Consensus
- Monorepo is preferred when a shared component library exists
- Tooling (Nx, Turborepo) is essential for monorepo at scale
- CI pipeline design is the critical differentiator

### Divergence
- **Claude** (Confidence: High): Monorepo with Nx, emphasizing that shared
  library versioning in polyrepo creates significant coordination overhead
- **GPT-5.3** (Confidence: Medium): Monorepo for now, but plan polyrepo
  migration path if teams grow beyond 30 engineers
- **Gemini** (Confidence: High): Monorepo with strict code ownership (CODEOWNERS),
  noting that Google-scale monorepos prove the pattern works

### Recommendation
Adopt a monorepo with Nx or Turborepo. Define strict code ownership
boundaries per service. The shared component library makes polyrepo
coordination cost prohibitive at this stage.

---
<details><summary>Claude Opus 4.6 Raw Response</summary>

=== PHASE 1: RESEARCH ===
- Monorepo: single repository for all services + shared code
- Polyrepo: separate repository per service
- Industry references: Google (monorepo), Netflix (polyrepo)
- Shared component library is the key constraint...

=== PHASE 2: ANALYSIS ===
- Trade-off matrix: coordination cost vs independence
- Monorepo: atomic cross-service refactors, single CI pipeline
- Polyrepo: independent deploy cycles, clearer ownership
- Initial recommendation: Monorepo with Nx...

=== PHASE 3: CRITIQUE ===
- Challenge: Monorepo CI becomes bottleneck at scale
- Missed: Team autonomy and hiring implications
- Edge case: What if services diverge to different languages?
- Confidence in Phase 2 recommendation: Medium...

=== PHASE 4: TEAM CONCLUSION ===
Monorepo with Nx. The shared library makes this decisive. Added caveats
from critique: plan CI sharding early, establish CODEOWNERS from day one.
Confidence: High (critique strengthened rather than weakened the recommendation)

</details>

<details><summary>GPT-5.3-Codex Raw Response</summary>
[full 4-phase response]
</details>

<details><summary>Gemini 3.1 Pro Raw Response</summary>
[full 4-phase response]
</details>
```

## Example 7: Fast Mode vs Team Mode Comparison

### Fast Mode (`COUNCIL_MODE=fast`)

```bash
COUNCIL_MODE=fast bash scripts/ask-council.sh "Is GraphQL or REST better for a mobile app backend?" 180
```

Each model returns a **single direct response** without internal deliberation phases:

```
=== CLAUDE / Claude-Opus-4.6 RESPONSE (exit: 0) ===
GraphQL is generally better for mobile because...

=== CODEX / GPT-5.3-Codex RESPONSE (exit: 0) ===
It depends on the complexity...

=== GEMINI / Gemini-3.1-Pro RESPONSE (exit: 0) ===
REST for simple CRUD, GraphQL for complex data requirements...
```

### Team Mode (`COUNCIL_MODE=team`, default)

```bash
bash scripts/ask-council.sh "Is GraphQL or REST better for a mobile app backend?" 180
```

Each model returns a **structured 4-phase deliberation**:

```
=== CLAUDE / Claude-Opus-4.6 RESPONSE (exit: 0) ===
=== PHASE 1: RESEARCH ===
[facts, prior art, constraints]

=== PHASE 2: ANALYSIS ===
[trade-off evaluation, initial recommendation]

=== PHASE 3: CRITIQUE ===
[challenges, edge cases, confidence rating]

=== PHASE 4: TEAM CONCLUSION ===
[refined final recommendation with caveats]

=== CODEX / GPT-5.3-Codex RESPONSE (exit: 0) ===
=== PHASE 1: RESEARCH ===
...
```

**Key difference**: Team mode produces deeper, self-critiqued analysis. The synthesizer uses Phase 4 conclusions for the final synthesis, while Phase 1-3 details are preserved in raw response sections.

---

## Using Council in Claude Code

Within a Claude Code session, the council is invoked automatically for substantive questions. You can also explicitly trigger it:

```
/council What is the best approach to implement rate limiting in a distributed system?
```

The current session (pure synthesizer) will:
1. Dispatch to all 3 models (Claude, Codex, Gemini) in parallel via `ask-council.sh`
2. Parse structured responses from all 3 independent sessions
3. Synthesize the final Council output (consensus, divergence, recommendation)
