# Proof of Concept: Pure Terraform State World Model

## Status: ✅ WORKING

Successfully demonstrated that a world model can live entirely in Terraform state with zero external JSON files.

## What We Built

**File**: `terraform/pure_world_prototype.tf`
**Test**: `test_pure_world.sh`

### Architecture

```
Iteration N:
  ↓
Read terraform.tfstate (previous facts)
  ↓
Merge with new input fact
  ↓
Local evaluation computes inferences
  ↓
Create/update terraform_data resources
  ↓
State now contains N+1 facts
```

### Key Innovation

**Self-referential state**: The Terraform config reads its own `.tfstate` file to load previous facts, then adds new facts and inferences. Each `terraform apply` is one reasoning step.

```hcl
locals {
  # Read our own state file
  previous_state = jsondecode(file("terraform.tfstate"))

  # Extract facts from previous iteration
  previous_facts = { ... parse state resources ... }

  # Add new fact this iteration
  new_facts = var.new_fact != null ? {...} : {}

  # Accumulate knowledge
  accumulated_facts = merge(previous_facts, new_facts)
}

# Facts as resources - persist in state
resource "terraform_data" "fact" {
  for_each = local.accumulated_facts
  input = each.value
}
```

### Inference as Locals

Pattern matching and inference happen through local value computation:

```hcl
locals {
  # Pattern: find all cities
  city_facts = {
    for k, v in local.all_facts : k => v
    if v.predicate == "is_a" && v.object == "city"
  }

  # Pattern: find city locations
  location_facts = {
    for k, v in local.all_facts : k => v
    if v.predicate == "located_in"
  }

  # INFERENCE: If (X is_a city) and (X located_in Y) then (Y is_a country)
  inferred_countries = {
    for lk, lv in local.location_facts :
    "inferred_country_${lv.object}" => {
      subject   = lv.object
      predicate = "is_a"
      object    = "country"
      iteration = var.iteration
      inferred  = true
    }
    if contains([for ck, cv in local.city_facts : cv.subject], lv.subject)
  }
}

# Inferred facts become resources too
resource "terraform_data" "inferred_fact" {
  for_each = local.all_inferred
  input = each.value
}
```

## Demo Results

```bash
$ ./test_pure_world.sh

Step 1: Add (Paris, is_a, city)
  → Creates fact_1 in state

Step 2: Add (Paris, located_in, France)
  → Loads fact_1 from state
  → Creates fact_2 in state
  → INFERS (France, is_a, country)
  → Creates inferred_country_France in state

Knowledge Base:
{
  "fact_1" = { subject="Paris", predicate="is_a", object="city" }
  "fact_2" = { subject="Paris", predicate="located_in", object="France" }
  "inferred_country_France" = { subject="France", predicate="is_a", object="country", inferred=true }
}

Statistics:
  total_facts = 2
  inferred_facts = 1
  total_knowledge = 3
```

## What This Proves

1. **No external JSON needed**: World model lives entirely in `.tfstate`
2. **Self-referential reasoning**: Config reads its own state to accumulate knowledge
3. **Inference via graph evaluation**: Terraform's dependency graph drives reasoning
4. **State as truth**: The `.tfstate` file IS the complete world model
5. **REPL-like loop**: Each `terraform apply` is one inference pass

## Implications

### This Enables

- **True homoiconicity**: Data and code in same system (state)
- **Version-controlled reasoning**: Git tracks the entire world model
- **Declarative inference**: Rules are data (HCL locals), not imperative code
- **Graph-based causality**: Terraform's DAG becomes reasoning graph
- **Auditability**: Every reasoning step persisted in state

### Alignment with 12-Factor

Like 12-factor apps store config in the environment, we store the world model in the "environment" (Terraform state). No external databases or files needed.

### Comparison to Current Architecture

**Current** (Phase 3):
- Python reads multiset.json and triples.json
- Python executes state machine
- Python writes updated JSON
- Terraform persists JSON files
- State split between .tfstate and .json

**Pure Terraform** (This prototype):
- Terraform reads terraform.tfstate
- Terraform locals execute inference
- Terraform writes updated state
- Single source of truth: .tfstate

## Challenges Discovered

### 1. State Structure

terraform_data stores input as:
```json
{
  "type": ["object", {...schema...}],
  "value": {...actual data...}
}
```

Must extract `.value` when reading from state.

### 2. Bootstrap

First iteration has no state file. Need graceful handling:
```hcl
previous_state = fileexists(local.state_file) ? jsondecode(file(local.state_file)) : null
```

### 3. HCL Verbosity

Pattern matching in HCL is more verbose than Python:
```python
# Python
cities = [f for f in facts if f.predicate == "is_a" and f.object == "city"]

# HCL
cities = { for k, v in facts : k => v if v.predicate == "is_a" && v.object == "city" }
```

But it's declarative and auditable.

## Next Steps

### Phase 1: Migrate Current System

1. Remove multiset.json and triples.json
2. Store all facts in terraform_data resources
3. Keep Python for now (just for parsing)

### Phase 2: Pure Terraform Inference

1. Express current operations.json rules as locals
2. Move pattern matching to HCL
3. Minimal/no Python

### Phase 3: Recurrent Optimization

1. Iterative inference until convergence
2. Dynamic pattern generation
3. Self-modifying inference rules
4. True homoiconic reasoning

### Phase 4: Advanced Capabilities

1. Contradiction detection (state consistency checks)
2. Temporal reasoning (iteration history in state)
3. Confidence from observation counts (already prototyped)
4. Query interface (outputs with filtered views)

## Open Questions

1. **Performance**: How does state file parsing scale?
   - Current: Works fine for 10s of facts
   - Expected: Should handle 100s-1000s
   - Unknown: Performance at 10k+ facts

2. **State file locking**: Concurrent applies?
   - Current: Sequential only
   - Could explore Terraform workspaces

3. **Pattern complexity**: Can we express all operations.json rules in HCL?
   - Simple patterns: ✅ Proven
   - Transitive closure: ✅ Possible
   - Complex guards: 🤔 May need external data source

4. **Convergence detection**: How to know when inference is complete?
   - Option A: Check if inferred set is empty
   - Option B: Hash state, compare to previous
   - Option C: External loop script

## Philosophical Note

This makes Terraform a **logic programming language**:
- Resources = facts in database
- Locals = inference rules
- Dependency graph = proof search
- Apply = forward chaining step
- State = knowledge base

It's Datalog meets Infrastructure as Code.

The REPL (`terraform apply` loop) becomes reasoning iteration.

---

**Conclusion**: The vision is validated. The world model CAN and SHOULD live in Terraform state. This is the path forward.
