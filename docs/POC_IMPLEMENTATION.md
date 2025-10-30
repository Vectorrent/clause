# Clause POC: The Loop Architecture

## Core Concept

**Clause is not a one-shot system. It's an iterative conversation with a world model.**

The key insight: Multiple `terraform apply` calls in a loop, with a **"clause"** (gate) between each iteration where new information enters the system.

```
┌─────────────────────────────────────────────┐
│                                             │
│  User Input → [CLAUSE/Gate] → Terraform    │
│                     ↓                       │
│              terraform apply                │
│                     ↓                       │
│              State Updated                  │
│                     ↓                       │
│              Show Output                    │
│                     ↓                       │
│              Wait for Next Input            │
│                     │                       │
│                     └──────[LOOP]───────────┘
```

**The "clause"** is the checkpoint between iterations where:
1. System shows current understanding
2. User provides next input
3. Input gets converted to Terraform resources
4. Loop continues

## Foundational Theory: SKI Calculus + Multisets

### Why SKI Combinator Calculus?

[SKI combinator calculus](https://en.wikipedia.org/wiki/SKI_combinator_calculus) is a minimal computational system with three operations:

- **I** (Identity): `I x = x` (return input unchanged)
- **K** (Constant): `K x y = x` (return first, discard second)
- **S** (Substitution): `S x y z = x z (y z)` (apply x to z, and apply result to (y z))

**Relevance to Clause:**
1. **Minimal basis**: Any computable function can be expressed with S, K, I
2. **Composability**: Combinators compose without variables
3. **Stateless operations**: Each combinator is a pure transformation
4. **Resource representation**: We can represent reasoning operations as combinators

**Mapping to Terraform resources:**
```hcl
# I combinator: Identity transformation
resource "clause_combinator" "identity" {
  type = "I"
  # Passes input through unchanged
}

# K combinator: Select first
resource "clause_combinator" "select_first" {
  type = "K"
  # Returns first argument, discards second
}

# S combinator: Apply and combine
resource "clause_combinator" "apply_combine" {
  type = "S"
  # Substitution/application pattern
}
```

### Why Multisets?

[Multisets](https://en.wikipedia.org/wiki/Multiset) are collections where elements can appear multiple times (unlike sets).

**Relevance to Clause:**
1. **Belief representation**: Same fact can be observed multiple times → confidence
2. **Evidence accumulation**: Multiple pieces of evidence for same conclusion
3. **Natural for reasoning**: "I've seen 5 white swans" (multiset: {white_swan, white_swan, ...})
4. **Probabilistic interpretation**: Frequency → probability

**Example:**
```
Multiset of observations:
{
  "Paris is_a city": 3 occurrences,
  "Paris located_in France": 2 occurrences,
  "France is_a country": 1 occurrence
}

→ Confidence(Paris is_a city) = high (3 observations)
→ Confidence(Paris located_in France) = medium (2 observations)
```

**In Terraform:**
```hcl
resource "clause_observation" "paris_is_city_1" {
  fact = "Paris is_a city"
  timestamp = "2025-10-29T10:00:00Z"
}

resource "clause_observation" "paris_is_city_2" {
  fact = "Paris is_a city"
  timestamp = "2025-10-29T10:01:00Z"
}

# Data source aggregates into multiset
data "clause_multiset" "accumulated_beliefs" {
  observations = [
    clause_observation.paris_is_city_1.id,
    clause_observation.paris_is_city_2.id
  ]

  # Output: {
  #   "Paris is_a city": count = 2,
  #   confidence = 0.9
  # }
}
```

## Architecture: The Conversational Loop

### Phase 1: Bash-Driven Development Loop (Week 1)

**Goal**: Build a simple bash script that drives iterative terraform applies with user input between each iteration.

#### File Structure
```
clause/
├── loop.sh                 # Main loop script
├── terraform/
│   ├── main.tf            # Terraform configuration
│   ├── variables.tf       # Input variables
│   ├── state.tf           # State accumulation
│   └── outputs.tf         # What to show user
├── provider/              # Custom provider (simple POC)
│   └── (minimal Go code)
└── README.md
```

#### The Loop Script: `loop.sh`

```bash
#!/bin/bash

# Clause: Conversational reasoning loop
# Each iteration: User input → Terraform apply → Show output → Repeat

TERRAFORM_DIR="./terraform"
ITERATION=0
STATE_FILE="$TERRAFORM_DIR/terraform.tfstate"

echo "=== Clause: Iterative World Modeling ==="
echo "Type 'exit' to quit, 'show' to see current state"
echo

while true; do
  ITERATION=$((ITERATION + 1))
  echo "─────────────────────────────────────"
  echo "Iteration $ITERATION"
  echo "─────────────────────────────────────"

  # Show current understanding
  if [ $ITERATION -gt 1 ]; then
    echo
    echo "Current understanding:"
    (cd "$TERRAFORM_DIR" && terraform output -json | jq -r '.current_facts.value[]' 2>/dev/null)
    echo
  fi

  # Gate: Get user input (THE CLAUSE)
  echo -n "You: "
  read -r USER_INPUT

  # Handle meta-commands
  case "$USER_INPUT" in
    exit|quit)
      echo "Goodbye!"
      exit 0
      ;;
    show|state)
      echo
      echo "=== Full State ==="
      (cd "$TERRAFORM_DIR" && terraform show)
      continue
      ;;
    "")
      continue
      ;;
  esac

  # Write input to Terraform variable file
  cat > "$TERRAFORM_DIR/input.auto.tfvars" <<EOF
iteration = $ITERATION
user_input = "$USER_INPUT"
EOF

  # Apply terraform (build up state)
  echo
  echo "Clause: Processing..."
  (cd "$TERRAFORM_DIR" && terraform apply -auto-approve -compact-warnings) 2>&1 | grep -v "Refreshing state"

  # Show what Clause understood/derived
  echo
  echo "Clause:"
  (cd "$TERRAFORM_DIR" && terraform output -raw response 2>/dev/null || echo "(no response generated)")
  echo
done
```

#### Minimal Terraform Configuration: `terraform/main.tf`

```hcl
terraform {
  required_providers {
    # For POC, we'll use built-in resources + external data sources
    # Later: custom provider
  }
}

# Input from user
variable "iteration" {
  type    = number
  default = 0
}

variable "user_input" {
  type    = string
  default = ""
}

# Accumulated state: Multiset of observations
resource "terraform_data" "observations" {
  # This resource accumulates all observations
  # Using triggers to store history

  input = {
    iteration = var.iteration
    observation = var.user_input
    timestamp = timestamp()
  }

  # Keep all previous observations in triggers_replace
  # They'll accumulate in the state file
  lifecycle {
    create_before_destroy = false
  }
}

# Process input with external script (reasoning engine)
data "external" "process_input" {
  program = ["python3", "${path.module}/process.py"]

  query = {
    input = var.user_input
    iteration = var.iteration
    # Pass previous state for context
    previous_facts = jsonencode(try(terraform_data.observations.output, {}))
  }
}

# Extract entities and facts from input
locals {
  # Parse response from processing script
  extracted_entities = try(jsondecode(data.external.process_input.result.entities), [])
  extracted_facts = try(jsondecode(data.external.process_input.result.facts), [])
  response_text = try(data.external.process_input.result.response, "")

  # Accumulate facts over iterations
  all_facts = concat(
    try(jsondecode(terraform_data.observations.output.all_facts), []),
    local.extracted_facts
  )
}

# Update accumulated state
resource "terraform_data" "observations" {
  input = {
    iteration = var.iteration
    observation = var.user_input
    extracted_entities = local.extracted_entities
    extracted_facts = local.extracted_facts
    all_facts = jsonencode(local.all_facts)
    timestamp = timestamp()
  }

  output = {
    iteration = var.iteration
    all_facts = jsonencode(local.all_facts)
    entity_count = length(local.extracted_entities)
    fact_count = length(local.all_facts)
  }
}

# What to show the user
output "response" {
  value = local.response_text
}

output "current_facts" {
  value = local.all_facts
}

output "stats" {
  value = {
    iteration = var.iteration
    total_facts = length(local.all_facts)
    total_entities = length(local.extracted_entities)
  }
}
```

#### Processing Script: `terraform/process.py`

```python
#!/usr/bin/env python3
"""
Simple reasoning engine for Clause POC
Extracts entities and facts, generates responses
"""

import sys
import json
import re

def extract_entities(text):
    """Extract named entities (very simple for POC)"""
    # Capitalize words are entities
    entities = re.findall(r'\b[A-Z][a-z]+\b', text)
    return list(set(entities))

def extract_facts(text, entities):
    """Extract simple subject-predicate-object triples"""
    facts = []

    # Pattern: "X is a Y"
    matches = re.findall(r'(\w+)\s+is\s+a\s+(\w+)', text, re.IGNORECASE)
    for subject, obj in matches:
        facts.append(f"{subject} is_a {obj}")

    # Pattern: "X in Y" or "X located in Y"
    matches = re.findall(r'(\w+)\s+(?:in|located in)\s+(\w+)', text, re.IGNORECASE)
    for subject, obj in matches:
        facts.append(f"{subject} located_in {obj}")

    return facts

def apply_reasoning_rules(all_facts):
    """Apply simple inference rules"""
    derived = []

    # Rule: If X is_a city AND X located_in Y, then Y is_a country
    cities = [f.split()[0] for f in all_facts if "is_a city" in f]
    locations = {}
    for f in all_facts:
        if "located_in" in f:
            parts = f.split()
            if len(parts) >= 3:
                locations[parts[0]] = parts[2]

    for city in cities:
        if city in locations:
            country = locations[city]
            derived_fact = f"{country} is_a country"
            if derived_fact not in all_facts:
                derived.append(derived_fact)

    return derived

def generate_response(input_text, extracted_facts, all_facts):
    """Generate a response based on extracted information"""
    if not extracted_facts:
        return "I didn't extract any new facts from that input."

    response_parts = []
    response_parts.append(f"I understood: {', '.join(extracted_facts)}")

    # Check for derived facts
    derived = apply_reasoning_rules(all_facts + extracted_facts)
    if derived:
        response_parts.append(f"I can infer: {', '.join(derived)}")

    return " ".join(response_parts)

def main():
    # Read input from Terraform
    input_data = json.loads(sys.stdin.read())

    user_input = input_data.get("input", "")
    iteration = int(input_data.get("iteration", 0))
    previous_facts_json = input_data.get("previous_facts", "[]")

    try:
        previous_facts = json.loads(previous_facts_json)
    except:
        previous_facts = []

    # Extract entities and facts
    entities = extract_entities(user_input)
    facts = extract_facts(user_input, entities)

    # Generate response
    all_facts = previous_facts + facts
    response = generate_response(user_input, facts, all_facts)

    # Output JSON for Terraform
    output = {
        "entities": json.dumps(entities),
        "facts": json.dumps(facts),
        "response": response
    }

    print(json.dumps(output))

if __name__ == "__main__":
    main()
```

### How It Works

1. **User starts the loop**: `./loop.sh`
2. **Iteration 1**:
   - User: `"Paris is a city"`
   - Script writes to `input.auto.tfvars`
   - `terraform apply --auto-approve` runs
   - `process.py` extracts: `["Paris is_a city"]`
   - State accumulates fact
   - Output: `"I understood: Paris is_a city"`

3. **Iteration 2**:
   - Shows: "Current understanding: Paris is_a city"
   - User: `"Paris is in France"`
   - Script processes input
   - `process.py` extracts: `["Paris located_in France"]`
   - Reasoning rule fires: `"France is_a country"` (derived!)
   - State accumulates: 2 base facts + 1 derived
   - Output: `"I understood: Paris located_in France. I can infer: France is_a country"`

4. **Iteration N**:
   - State keeps growing
   - More facts → more inferences
   - User can query: `"What do you know about France?"`
   - System searches accumulated facts

### Multiset Implementation

Enhance `process.py` to track observation counts:

```python
def update_multiset(previous_multiset, new_facts):
    """Add facts to multiset, tracking counts"""
    multiset = previous_multiset.copy()

    for fact in new_facts:
        if fact in multiset:
            multiset[fact] += 1
        else:
            multiset[fact] = 1

    return multiset

def compute_confidence(count, total_observations):
    """Convert observation count to confidence"""
    # Simple frequency-based confidence
    return min(count / (total_observations + 1), 0.99)
```

Store in state:
```hcl
resource "terraform_data" "fact_multiset" {
  input = {
    iteration = var.iteration
    # JSON: {"Paris is_a city": 3, "France is_a country": 1}
    multiset = local.updated_multiset
  }
}
```

### SKI Combinator Implementation

Add combinator-based reasoning:

```python
# SKI Combinators as functions
def I(x):
    """Identity: I x = x"""
    return x

def K(x):
    """Constant: K x = λy.x"""
    return lambda y: x

def S(x):
    """Substitution: S x y z = x z (y z)"""
    return lambda y: lambda z: x(z)(y(z))

# Use combinators for reasoning operations
def identity_reasoning(fact):
    """Pass fact through unchanged"""
    return I(fact)

def select_fact(fact1, fact2):
    """Select first fact, discard second"""
    return K(fact1)(fact2)

def compose_reasoning(rule1, rule2, fact):
    """Apply both rules and combine"""
    return S(rule1)(rule2)(fact)
```

Why this matters:
- **Composable reasoning**: Build complex rules from simple combinators
- **Provable correctness**: SKI is well-studied, formal semantics
- **Minimal primitives**: Only need S, K, I to express any reasoning

## Implementation Timeline

### Week 1: Basic Loop
- [x] Research completed
- [ ] Write `loop.sh` script
- [ ] Create minimal `main.tf`
- [ ] Implement `process.py` with entity/fact extraction
- [ ] Test conversational loop
- **Goal**: Can have multi-turn conversation that accumulates facts

### Week 2: Multisets
- [ ] Enhance `process.py` to track observation counts
- [ ] Store multiset in Terraform state
- [ ] Compute confidence from frequencies
- [ ] Test: "Paris is a city" × 3 → high confidence
- **Goal**: System learns from repeated observations

### Week 3: SKI Combinators
- [ ] Implement S, K, I combinators in `process.py`
- [ ] Express reasoning rules as combinator compositions
- [ ] Create combinator resources in Terraform
- [ ] Test: Build complex rules from simple combinators
- **Goal**: Demonstrate combinator-based reasoning

### Week 4: Refinement
- [ ] Add query capability ("What do you know about X?")
- [ ] Improve inference rules
- [ ] Add visualization (fact graph)
- [ ] Performance optimization
- **Goal**: Usable conversational reasoning system

## Testing the POC

### Setup
```bash
cd clause
chmod +x loop.sh

# Initialize Terraform
cd terraform
terraform init
cd ..
```

### Test Conversation
```
$ ./loop.sh

=== Clause: Iterative World Modeling ===

─────────────────────────────────────
Iteration 1
─────────────────────────────────────
You: Paris is a city

Clause: Processing...
terraform_data.observations: Creating...
terraform_data.observations: Creation complete

Clause:
I understood: Paris is_a city

─────────────────────────────────────
Iteration 2
─────────────────────────────────────
Current understanding:
- Paris is_a city

You: Paris is located in France

Clause: Processing...
terraform_data.observations: Modifying...
terraform_data.observations: Modifications complete

Clause:
I understood: Paris located_in France. I can infer: France is_a country

─────────────────────────────────────
Iteration 3
─────────────────────────────────────
Current understanding:
- Paris is_a city
- Paris located_in France
- France is_a country [derived]

You: What do you know about France?

Clause: Processing...

Clause:
I know: France is_a country, Paris located_in France
```

## Key Differences from Original Plan

**Before**: One-shot Terraform config that represents entire reasoning process

**Now**:
- Iterative loop with terraform as state manager
- Bash script orchestrates the conversation
- Each `terraform apply` is one reasoning step
- State accumulates over iterations
- User provides input at each "clause" (gate)

**Why better**:
- More natural for conversation
- Easier to debug (one step at a time)
- State evolution is explicit
- Mirrors human reasoning (iterative, not one-shot)

## Production Evolution

Once POC works, scale to production:

### Data-Driven Loop
Replace user input with data sources:
```bash
# Instead of: read USER_INPUT
# Use: USER_INPUT=$(fetch_from_api)
# Or: USER_INPUT=$(tail -n1 stream.log)
```

### Custom Provider
Move from `external` data sources to proper Go provider:
- Faster execution
- Better state management
- Native multiset support
- Optimized combinator operations

### Parallel Reasoning
Multiple Terraform workspaces running in parallel:
```bash
# Workspace 1: Processing user input
terraform workspace select user-input
terraform apply

# Workspace 2: Background inference
terraform workspace select inference
terraform apply

# Merge states periodically
```

## Why This Works

1. **Terraform is the state manager** (not the reasoner)
   - State file = world model
   - Dependencies = relationships
   - Apply = state transition

2. **Python/Go is the reasoner**
   - Extract facts
   - Apply rules
   - Generate responses

3. **Bash is the orchestrator**
   - Manages the loop
   - Gates between iterations
   - Coordinates input/output

4. **User is the teacher** (in development)
   - Provides training data through conversation
   - Corrects misunderstandings
   - Guides reasoning

**Each component does what it's good at.**

## Next Steps

1. **Implement basic loop** (Week 1)
2. **Test conversational flow**
3. **Add multiset tracking** (Week 2)
4. **Implement SKI combinators** (Week 3)
5. **Evaluate and iterate**

---

**Ready to build?** Start with the bash script and minimal Terraform config. Get the loop working first, then add sophistication.

The key is: **The loop is the system.** Not the provider, not the config—the iterative conversation itself.
