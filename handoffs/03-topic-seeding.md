# Handoff 03 — Topic Seeding & Math Curriculum

## Context

The database schema has a `topic` table and a `topic_type` lookup table. The `topic_type`
rows are seeded by `backend/seed.py` (run that first). The `topic` table is empty —
this handoff fills it with real content.

Read `CLAUDE.md` for the full topic type ID convention before writing any IDs.
Read `backend/models.py` for the `Topic` schema.
Read `backend/seed.py` to understand the seed pattern.

---

## Topic schema

```python
class Topic(BaseModel):
    id           = Column(UUID)           # uuid4
    name         = Column(String(128))    # display name
    topic_type_id = Column(Integer)       # FK → topic_type.id (see CLAUDE.md)
    description  = Column(Text)           # 1–3 sentences used as LLM context seed
    created_at   = Column(DateTime(tz))
```

---

## Task 1 — General knowledge topics

Add to `backend/seed.py` a `TOPICS` list and a `seed_topics()` function (idempotent —
check `db.query(Topic).filter(Topic.name == t.name).first()` before inserting).

Seed at minimum the following topics. Write a 1–3 sentence `description` for each —
the description is injected directly into the LLM prompt as context, so make it
informative and specific.

### Persons & Organizations (1xxx)

| name | topic_type_id | description hint |
|---|---|---|
| Otto von Bismarck | 1276 | Iron Chancellor, unification of Germany, Realpolitik |
| Marie Curie | 1250 | First woman Nobel Prize (×2), radioactivity, wartime X-ray units |
| Ada Lovelace | 1826 | First algorithm, collaboration with Babbage, Victorian computing |
| Frederick Douglass | 1840 | Abolitionist, *Narrative*, influence on Lincoln |
| Nikola Tesla | 1840 | AC current, rivalry with Edison, patents, later life |

### Historical Events (2xxx)

| name | topic_type_id | description hint |
|---|---|---|
| WWI — Origins & Alliances | 2276 | Triple Alliance vs Entente, Bismarck's legacy, July Crisis |
| The French Revolution | 2250 | Causes, phases (moderate → radical → Thermidor), legacy |
| Indian Independence Movement | 2356 | Gandhi, non-cooperation, partition, 1947 |
| American Civil War | 2840 | Causes beyond slavery (tariffs, states' rights), major battles, Reconstruction |
| The Manhattan Project | 2840 | Los Alamos, key scientists, ethical debates |

### Geography (3xxx)

| name | topic_type_id | description hint |
|---|---|---|
| The Rhine Valley | 3276 | Industrial heartland, Lorelei, wine regions, NATO significance |
| The Ganges River | 3356 | Religious significance, water crisis, pollution paradox |
| The American Great Plains | 3840 | Dust Bowl, agriculture, Indigenous displacement |

### Arts (4xxx)

| name | topic_type_id | description hint |
|---|---|---|
| Beethoven's Late Period | 4200 | Deafness, 9th Symphony, late string quartets, influence on Romanticism |
| Impressionism | 4100 | Monet, light and colour, break from academic tradition, Paris Salon |
| Shakespeare's Tragedies | 4400 | Hamlet, Lear, Macbeth — tragic flaw, revenge, power |

### Science (5xxx)

| name | topic_type_id | description hint |
|---|---|---|
| Mendelian Genetics | 5300 | Pea experiments, dominant/recessive, rediscovery in 1900 |
| Special Relativity | 5100 | 1905, E=mc², simultaneity, time dilation — conceptual not mathematical |
| The Periodic Table | 5200 | Mendeleev's prediction gaps, atomic number vs mass, periodicity |

---

## Task 2 — Math curriculum (6xxx topics)

The math topics are sequential — design them so `cron.py`'s topic rotation progresses
through concepts in order. Each topic covers one concept; questions build week-to-week.

### Calculus (6100) — 8 topics

```
1.  Limits & Continuity          — ε-δ definition, one-sided limits, removable discontinuities
2.  Derivatives — Definition     — limit definition, tangent line, differentiability
3.  Derivatives — Rules          — power, product, quotient, chain rule
4.  Derivatives — Applications   — critical points, inflection points, optimisation
5.  Integration — Antiderivatives — indefinite integrals, u-substitution
6.  Integration by Parts         — ∫u dv = uv − ∫v du, choosing u with LIATE
7.  Definite Integrals & FTC     — Fundamental Theorem, area under curve
8.  Improper Integrals           — infinite bounds, p-series convergence test
```

### Linear Algebra (6200) — 8 topics

```
1.  Vectors & Vector Spaces      — span, linear independence, basis, dimension
2.  Matrix Operations            — addition, multiplication, transpose, inverse
3.  Systems of Equations         — row reduction, RREF, solution sets
4.  Determinants                 — cofactor expansion, geometric meaning (area/volume)
5.  Eigenvalues & Eigenvectors   — characteristic polynomial, diagonalisation
6.  Orthogonality & Projections  — dot product, Gram-Schmidt, QR decomposition
7.  SVD                          — singular value decomposition, rank, image compression
8.  Linear Transformations       — kernel, image, rank-nullity theorem
```

### Statistics (6300) — 6 topics *(future, after Calculus + LinAlg are done)*

```
1.  Descriptive Statistics       — mean/median/mode, variance, IQR, skewness
2.  Probability Fundamentals     — sample space, conditional probability, Bayes' theorem
3.  Distributions                — normal, binomial, Poisson — PMF/PDF, CDF
4.  Sampling & CLT               — sampling distributions, Central Limit Theorem
5.  Hypothesis Testing           — null/alternative, p-value, Type I/II errors
6.  Regression                   — OLS, R², residuals, assumptions
```

---

## Implementation

Extend `backend/seed.py`:

```python
from datetime import datetime, UTC
import uuid

TOPICS = [
    # (name, topic_type_id, description)
    ("Otto von Bismarck", 1276, "..."),
    # ... all rows above
]

def seed_topics(db):
    """Seed topic rows. Idempotent — skips existing names."""
    existing = {t.name for t in db.query(Topic.name).all()}
    now = datetime.now(UTC)
    for name, type_id, description in TOPICS:
        if name not in existing:
            db.add(Topic(
                id=uuid.uuid4(),
                name=name,
                topic_type_id=type_id,
                description=description,
                created_at=now,
            ))
    db.commit()
    print(f"Seeded {len(TOPICS)} topics.")
```

Call `seed_topics(db)` at the bottom of `seed()`.

---

## Cron rotation behaviour (for reference)

`cron.py`'s `_pick_topics()` rotates general topics by day-of-year offset and always
includes 2 math topics on weekdays. Once you have the topics seeded, verify the rotation
makes sense by calling `_pick_topics(db, date.today(), 7)` in a REPL and checking the output.

---

## Verification

```bash
cd backend
DATABASE_URL="..." uv run python seed.py
# Expected output:
# Seeded 5 topic types, 3 question types.
# Seeded 30 topics.    ← (or however many you add)

uv run python - <<'EOF'
from db import SessionLocal
from models import Topic
db = SessionLocal()
print(db.query(Topic).count(), "topics")
print(db.query(Topic).filter(Topic.topic_type_id >= 6000).count(), "math topics")
EOF
```
