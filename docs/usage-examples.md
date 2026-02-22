# Usage Examples

This document shows real-world scenarios where the Dual LLM Council adds value by combining perspectives from GPT-5.3-Codex and Gemini 3.1 Pro without exhausting Claude tokens.

## Example 1: Architecture Review

### Input

```bash
bash scripts/ask-council.sh "Review this architecture: A React SPA talks to a FastAPI backend. The backend uses SQLAlchemy with PostgreSQL. We're considering adding Redis for caching and Celery for background tasks. Current scale is 10K DAU, projected to reach 100K in 6 months. What are the risks and what would you change?" 180
```

### Expected Output Format

```markdown
## Council Synthesis (GPT-5.3 + Gemini 3.1 Pro)

### Consensus
- Redis caching is appropriate for this scale trajectory
- Celery + Redis as broker is a well-established pattern
- Connection pooling should be configured before scaling

### Divergence
- **GPT-5.3**: Emphasizes adding read replicas for PostgreSQL early and focusing on schema performance
- **Gemini**: Suggests considering Cloud Tasks / Pub-Sub instead of self-managed Celery

### Recommendation
Add Redis now for caching. Defer Celery until background task complexity
justifies it. Configure PgBouncer for connection pooling immediately.

---
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
bash scripts/ask-council.sh "We have a memory leak in a Node.js Express server. RSS grows by ~50MB/hour under load. The app uses Prisma ORM, Bull queues, and Socket.IO. What is the most likely cause and what is the systematic debugging approach?" 180
```

### Expected Output Format

```markdown
## Council Synthesis (GPT-5.3 + Gemini 3.1 Pro)

### Consensus
- Bull queue job references can prevent garbage collection
- Heap snapshots with --inspect are the correct diagnostic tool

### Divergence
- **GPT-5.3**: Points to Prisma connection pool exhaustion and dangling sockets as equally likely
- **Gemini**: Recommends clinic.js as the first diagnostic step to overview event loops

### Recommendation
1. Take heap snapshots at 0, 30, 60 min with `--inspect`
2. Compare retained objects — look for Socket.IO listeners and Bull job refs
3. Check Prisma connection pool settings (pool size, timeout)

---
<details><summary>GPT-5.3-Codex Raw Response</summary>
[full response]
</details>

<details><summary>Gemini 3.1 Pro Raw Response</summary>
[full response]
</details>
```

## Example 3: Context Files (Untrusted Load)

### Input

```bash
CONTEXT_FILES="src/app.ts:tests/app.test.ts" bash scripts/ask-council-debate.sh "Refactor this Express application logic into a domain-driven structure." 300
```

This will automatically wrap the contents of `src/app.ts` and `tests/app.test.ts` into an `<UNTRUSTED CONTEXT>` block before piping it directly into both Codex and Gemini for debate analysis. It safeguards your environment by limiting the max bytes extracted and skipping binary files.

## Example 4: Complex Problem Solving (Debate Mode)

### Input

```bash
bash scripts/ask-council-debate.sh "We need to migrate a 2TB PostgreSQL database from on-premise to AWS RDS with less than 1 hour of downtime. The database has 500+ tables, heavy foreign key constraints, and receives ~5000 writes/sec during business hours. What migration strategy do you recommend?" 300
```

### Expected Output Format

```markdown
## Council Synthesis (GPT-5.3 + Gemini 3.1 Pro)

### Consensus
- AWS DMS (Database Migration Service) with CDC (Change Data Capture) is
  the standard approach
- Full load + CDC replication minimizes downtime
- Foreign key constraints should be disabled during initial load

### Divergence
- **GPT-5.3**: Suggests a two-phase approach: DMS for bulk + custom
  pg_dump/restore for edge cases DMS handles poorly
- **Gemini**: Recommends using AWS SCT (Schema Conversion Tool) first to
  identify incompatibilities, even for homogeneous migration

### Recommendation (From Round 5 Repaired Convergence)
1. Use AWS DMS with CDC for continuous replication
2. Disable FK constraints and triggers on target during full load
3. Run parallel validation with pg_verify_checksums
4. Schedule cutover during lowest-traffic window
5. Target: 15-30 min actual downtime for DNS switch + final sync

---
<details><summary>GPT-5.3-Codex Raw Response</summary>
[full response]
</details>

<details><summary>Gemini 3.1 Pro Raw Response</summary>
[full response]
</details>
```

## Example 5: Lens Mode for Extreme Diversity

### Input

```bash
COUNCIL_LENS=lens bash scripts/ask-council-debate.sh "Should we use a monorepo or polyrepo for a microservices architecture with 5 services and a shared component library?" 240
```

Each model will apply a unique lens to the problem (Codex = ROI / Maximum Impact, Gemini = Speed / Execution Simplicity) to force diverse conclusions before the converge round.