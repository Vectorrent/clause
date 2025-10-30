# Pure Terraform World Model

## Vision

**The Terraform state IS the world model.** No external files. Minimal or no external processing.

Following 12-factor principles: configuration (patterns, rules) in the environment (Terraform variables/locals), and state (facts, triples, inferences) in Terraform state.

## Current Architecture (External State)

```
Input → Python (patterns, operations, state machine) → JSON files ← Terraform reads/writes
        ↑                                               ↓
        └───────── Loads from external JSON ────────────┘
```

**Problems:**
- multiset.json, triples.json are outside Terraform state
- Python is the reasoning engine, Terraform is just persistence
- State is split between .tfstate and .json files
- World model isn't in "the world"

## New Architecture (Pure Terraform State)

```
Input → Terraform (locals evaluate inference) → State (.tfstate)
        ↑                                        ↓
        └────── References previous state ──────┘
```

**Principles:**
- Terraform state contains ALL facts, triples, patterns, operations
- Inference = local value computation over state
- Terraform's dependency graph = causal reasoning graph
- Each apply = one inference pass
- Recurrence through iteration variables and state references

## Implementation Sketch

### 1. Facts as Resources

```hcl
# Each triple is a resource in state
resource "terraform_data" "triple" {
  for_each = local.all_triples  # Set of [subj, pred, obj]

  input = {
    subject   = each.value[0]
    predicate = each.value[1]
    object    = each.value[2]
    count     = local.triple_counts[each.key]
    iteration = var.iteration
  }

  lifecycle {
    # Never destroy facts - accumulate knowledge
    prevent_destroy = false  # Actually want this false for experiments
  }
}
```

### 2. Inference as Locals

```hcl
# Read previous state (from data source or state read)
data "terraform_remote_state" "previous" {
  backend = "local"
  config = {
    path = "${path.module}/terraform.tfstate"
  }
}

# Pattern matching: if (X, is_a, city) and (X, located_in, Y) then (Y, is_a, country)
locals {
  # Extract existing triples from state
  existing_triples = {
    for k, v in data.terraform_remote_state.previous.outputs.triples :
    k => [v.subject, v.predicate, v.object]
  }

  # Pattern: cities
  cities = {
    for k, v in local.existing_triples :
    v[0] => v if v[1] == "is_a" && v[2] == "city"
  }

  # Pattern: city locations
  city_locations = {
    for k, v in local.existing_triples :
    v[0] => v[2] if v[1] == "located_in" && contains(keys(local.cities), v[0])
  }

  # INFERENCE: derive country types
  inferred_countries = {
    for city, location in local.city_locations :
    "${location}_is_a_country" => [location, "is_a", "country"]
  }

  # Merge new input triple + inferred triples
  all_triples = merge(
    local.existing_triples,
    local.input_triple,
    local.inferred_countries
  )
}
```

### 3. Pattern Extraction as Locals

```hcl
variable "user_input" {
  type = string
}

locals {
  # Pattern matching on input (could be list of patterns)
  is_a_pattern = regex("(\\w+)\\s+is\\s+a\\s+(\\w+)", var.user_input)

  input_triple = can(local.is_a_pattern) ? {
    "input_${var.iteration}" = [
      local.is_a_pattern[0],  # subject
      "is_a",
      local.is_a_pattern[1]   # object
    ]
  } : {}
}
```

### 4. Confidence from Counts

```hcl
# Multiset = count per triple
locals {
  # Count occurrences across iterations
  triple_counts = {
    for k, v in local.all_triples :
    k => lookup(data.terraform_remote_state.previous.outputs.counts, k, 0) + 1
  }

  # Confidence = normalized frequency
  max_count = max(values(local.triple_counts)...)
  confidence = {
    for k, count in local.triple_counts :
    k => count / (max_count + 1)
  }
}
```

### 5. Recurrent Logic with Null Resources

```hcl
# Iterative inference: keep applying rules until convergence
resource "null_resource" "inference_pass" {
  count = local.new_inferences_found ? 1 : 0

  triggers = {
    iteration = var.iteration
    inferred  = jsonencode(local.inferred_countries)
  }

  # Could trigger additional apply passes
}
```

## Key Advantages

1. **Single Source of Truth**: .tfstate is the complete world model
2. **Graph-Based Reasoning**: Terraform's dependency graph naturally orders inference
3. **Declarative**: All logic in HCL, not imperative Python
4. **Versioned**: State is version-controllable, auditable
5. **Compositional**: Locals compose into higher-order inferences
6. **Homoiconic**: The data describing reasoning IS in the reasoning system

## Challenges

1. **State Self-Reference**: How to read previous state during apply?
   - Option A: `data.terraform_remote_state` pointing to self
   - Option B: Read .tfstate file directly as JSON
   - Option C: Accept previous state as variable input (external loop)

2. **Pattern Complexity**: Regex and pattern matching in HCL is verbose
   - Could use templatefile() for complex patterns
   - Or minimal external data source just for parsing

3. **Inference Loops**: How to iterate inference until convergence?
   - External loop script that runs apply multiple times
   - Or null_resource with triggers
   - Or accept one inference pass per apply

4. **Bootstrapping**: First iteration has no previous state
   - Use try() and defaults
   - Or seed state with axioms

## Migration Path

**Phase 1**: Move facts from JSON to pure state
- Keep Python for now
- Store all triples in terraform_data resources
- Remove multiset.json, triples.json

**Phase 2**: Move inference to Terraform locals
- Express simple inference rules as locals
- Python becomes minimal input parser
- Core reasoning in HCL

**Phase 3**: Remove Python entirely (optional)
- All pattern matching in HCL or minimal external data source
- Pure Terraform reasoning loop

**Phase 4**: Recurrent optimization
- Self-modifying inference rules
- Dynamic pattern learning
- State-driven exploration

## Philosophical Implications

This makes Terraform a **logic programming language** where:
- Resources = facts in a database
- Locals = inference rules
- Dependency graph = proof search order
- Apply = one step of forward chaining
- State = accumulated knowledge base

It's Datalog meets Infrastructure as Code meets World Modeling.

The loop (terraform apply loop) becomes the REPL for exploring the state space.

## Next Steps

1. Prototype simple inference in pure HCL
2. Test state self-reference patterns
3. Benchmark performance vs Python
4. Design pattern DSL in HCL
5. Implement recurrent convergence detection
