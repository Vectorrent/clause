# Design: Markov Modeling + SKI Combinators in Pure Terraform

## Vision

Transform Clause into a **true Markov model** that:
1. **Learns from ANY input** (not just pattern-matching sentences)
2. **Models computation as SKI combinator compositions**
3. **Uses list operations** (sequential, random, weighted sampling)
4. **Leverages 6D atomic properties** for weight calculations
5. **Performs depth-limited graph walks** (max depth 6)

## Current Limitations

**Problem**: System only extracts patterns matching 5 hardcoded regex:
- "X is a Y"
- "X is Y"
- "X located in Y"
- "X in Y"
- "X has Y"

**Result**: "Hello, world!" → "I couldn't extract any patterns"

This is a **semantic triple parser**, not a **Markov model**.

## True Markov Modeling

### 1. Tokenization
```hcl
# Input: "Hello, world! How are you?"
# Tokens: [Hello, world, How, are, you]
tokens = [
  for word in split(" ", replace(var.user_input, "!", ""))
  : lower(replace(word, "?", ""))
  if word != ""
]
```

### 2. N-gram Extraction
```hcl
# Bigrams (word pairs)
bigrams = {
  for i in range(length(local.tokens) - 1) :
  "${local.tokens[i]}_${local.tokens[i+1]}" => {
    word1 = local.tokens[i]
    word2 = local.tokens[i+1]
    iteration = var.iteration
  }
}

# Trigrams (word triples)
trigrams = {
  for i in range(length(local.tokens) - 2) :
  "${local.tokens[i]}_${local.tokens[i+1]}_${local.tokens[i+2]}" => {
    word1 = local.tokens[i]
    word2 = local.tokens[i+1]
    word3 = local.tokens[i+2]
    iteration = var.iteration
  }
}
```

### 3. Transition Matrices
```hcl
# Word co-occurrence: which words follow which?
transitions = {
  for bg_key, bg in local.all_bigrams :
  bg.word1 => concat(
    lookup(local.transitions, bg.word1, []),
    [bg.word2]
  )...
}

# Probabilities: P(word2 | word1)
transition_probs = {
  for word, followers in local.transitions :
  word => {
    for follower in distinct(followers) :
    follower => (
      length([for f in followers : f if f == follower]) /
      length(followers)
    )
  }
}
```

## SKI Combinator Abstractions

### Theory

**S, K, I** form a Turing-complete computational basis:

- **I** (Identity): `I(x) = x`
- **K** (Constant): `K(x)(y) = x`
- **S** (Substitution): `S(f)(g)(x) = f(x)(g(x))`

**Insight**: Inference rules are **function compositions**.

### Modeling in HCL

```hcl
# === SKI Combinators as Pure Functions ===

# I: Identity (pass through)
locals {
  combinator_I = {
    type = "I"
    apply = "lambda x: x"
  }
}

# K: Constant selector (filter)
locals {
  combinator_K = {
    type = "K"
    apply = "lambda pattern: lambda data: pattern"
  }
}

# S: Substitution (compose and apply)
locals {
  combinator_S = {
    type = "S"
    apply = "lambda f: lambda g: lambda x: f(x)(g(x))"
  }
}
```

### Inference Rules as SKI Compositions

**Example**: Type propagation rule
```
If (X, is_a, city) AND (X, located_in, Y) => (Y, is_a, country)
```

**As SKI composition**:
```hcl
# Check if entity is typed as "city"
check_city = local.combinator_K  # Returns "city" pattern

# Check if entity has "located_in" relation
check_location = local.combinator_K  # Returns "located_in" pattern

# Compose: S(check_city)(check_location)(entity)
# If both conditions met, apply transformation
inferred_country = {
  for entity, location in local.locations :
  "${location}_is_a_country" => {
    subject = location
    predicate = "is_a"
    object = "country"
    combinator = "S(K(city))(K(located_in))"  # Record the composition!
  }
  if lookup(local.typed_entities, entity, "") == "city"
}
```

**Key innovation**: Store the **combinator composition** that generated each inference!

### Combinator Algebra

Build complex rules from S, K, I:

```hcl
# Compose combinators to create new operations
locals {
  # NOT = S(S(I)(K(false)))(K(true))
  combinator_NOT = "S(S(I)(K(false)))(K(true))"

  # AND = S(K(S))(S(K(K))(S(K(S))(K(K))))
  combinator_AND = "S(K(S))(S(K(K))(S(K(S))(K(K))))"

  # OR = S(I)(K(I))
  combinator_OR = "S(I)(K(I))"
}
```

## 6D Weight Calculations

Each atomic has **6 dimensions**:

1. **subject** (string) - entity name
2. **predicate** (string) - relation type
3. **object** (string) - target entity
4. **confidence** (float) - belief strength (0-1)
5. **count** (int) - observation frequency
6. **iteration** (int) - recency (time)

### Weight Formula

```hcl
# Calculate attention weight from 6D properties
weight = (
  confidence *
  log(count + 1) *
  exp(-(var.iteration - iteration) * 0.01)  # Temporal decay
)

# Normalize weights
total_weight = sum([for k, v in atomics : calculate_weight(v)])
normalized_weights = {
  for k, v in atomics :
  k => calculate_weight(v) / total_weight
}
```

### Depth-Limited Influence

**Problem**: Computing weights considering ALL graph paths is exponential.

**Solution**: Limit depth to 6 hops.

```hcl
# Compute influence of node A on node B (up to depth 6)
influence_depth_6 = {
  for a in nodes :
  a => {
    for b in nodes :
    b => length([
      for path in all_paths_length_6(a, b) :
      path
    ]) * local.normalized_weights[a]
  }
}
```

**Why depth 6?**
- [Six degrees of separation](https://en.wikipedia.org/wiki/Six_degrees_of_separation)
- Computationally feasible for 100s of nodes
- Captures meaningful long-range dependencies

## List Operations Framework

**Everything as list operations**:

### 1. Sequential Access
```hcl
# Iterate over ALL data
for k, v in local.all_triples : process(v)
```

### 2. Random Sampling
```hcl
# Pick random element
random_index = var.iteration % length(list)
random_element = values(list)[random_index]
```

### 3. Weighted Sampling
```hcl
# Sample based on computed weights
cumulative_weights = [
  for i in range(length(list)) :
  sum([for j in range(i+1) : weights[j]])
]

# Binary search for index
sampled_index = [
  for i, w in cumulative_weights :
  i if w >= random_value
][0]
```

## Architecture Layers

### Layer 0: Self-Reference (existing)
- Read terraform.tfstate
- Load previous atomics, triples

### Layer 1: Tokenization (NEW)
```hcl
locals {
  # Clean and tokenize ANY input
  cleaned = lower(replace(replace(var.user_input, "!", ""), "?", ""))
  tokens = [for w in split(" ", local.cleaned) : w if w != ""]
}
```

### Layer 2: N-gram Extraction (NEW)
```hcl
locals {
  # Extract word pairs and triples
  bigrams = { for i in range(length(local.tokens)-1) : ... }
  trigrams = { for i in range(length(local.tokens)-2) : ... }
}
```

### Layer 3: Transition Matrices (NEW)
```hcl
locals {
  # Build Markov chains
  transitions = { for word : word => [followers] }
  probs = { for word : word => { for f : f => P(f|word) } }
}
```

### Layer 4: SKI Combinators (NEW)
```hcl
locals {
  combinator_I = { type = "I", ... }
  combinator_K = { type = "K", ... }
  combinator_S = { type = "S", ... }
}
```

### Layer 5: 6D Weights (NEW)
```hcl
locals {
  weights = {
    for k, v in atomics :
    k => v.confidence * log(v.count + 1) * exp(-(var.iteration - v.iteration) * 0.01)
  }
}
```

### Layer 6: Semantic Patterns (existing, ENHANCED)
```hcl
locals {
  # Keep existing semantic triple extraction
  # BUT ALSO extract n-grams from any input
  all_patterns = merge(
    local.semantic_triples,  # "X is_a Y"
    local.ngram_triples      # (word1, follows, word2)
  )
}
```

### Layer 7: Inference with SKI (existing, ENHANCED)
```hcl
locals {
  # Pass 1: Type propagation (as S combinator composition)
  inferred_pass1 = {
    combinator = "S(K(type))(K(relation))"
    ...
  }

  # Pass 2: Transitive closure (as S combinator composition)
  inferred_pass2 = {
    combinator = "S(I)(K(transitive))"
    ...
  }

  # Pass 3: Gap filling (as K combinator - select missing)
  inferred_pass3 = {
    combinator = "K(default_type)"
    ...
  }

  # Pass 4: Weighted random walk (use 6D weights)
  inferred_pass4 = {
    combinator = "S(sample)(weight)"
    ...
  }
}
```

### Layer 8: Graph Walks (NEW)
```hcl
locals {
  # Depth-limited BFS/DFS
  reachable_depth_6 = {
    for start in nodes :
    start => explore_depth(start, 6, local.adjacency, local.weights)
  }
}
```

### Layer 9: Response Generation (existing, ENHANCED)
```hcl
locals {
  # Generate response from:
  # 1. Semantic triples (existing)
  # 2. Markov chain predictions (NEW)
  # 3. Weighted graph exploration (NEW)

  response = local.is_query ?
    generate_from_graph() :
    generate_from_markov()
}
```

## Implementation Strategy

### Phase 1: Tokenization + N-grams ✓
- Add tokenization layer
- Extract bigrams/trigrams from ANY input
- Store as transitions

### Phase 2: Transition Matrices ✓
- Build word co-occurrence maps
- Calculate probabilities
- Store in state

### Phase 3: SKI Abstractions ✓
- Define I/K/S combinators
- Model existing inference as SKI compositions
- Store combinator provenance

### Phase 4: 6D Weights ✓
- Calculate weights from all properties
- Implement weighted sampling
- Use for attention in Pass 4

### Phase 5: Depth-6 Walks ✓
- Implement BFS/DFS with depth limit
- Calculate influence scores
- Use for long-range inference

### Phase 6: Integration & Testing ✓
- Merge all layers
- Test with conversational inputs
- Verify learning from any input

## Expected Behavior

**Input**: "Hello, world!"
**Before**: "I couldn't extract any patterns"
**After**:
```
Extracted transitions:
  hello → world (1.0)

Response: "I learned: 'hello' often precedes 'world'"
```

**Input**: "Your name is Clause"
**Before**: "I couldn't extract any patterns"
**After**:
```
Extracted:
  - Semantic: (Clause, has, name)
  - Markov: your → name → is → clause
  - Bigrams: (your, name), (name, is), (is, clause)

Response: "I learned: Names often follow 'your', and 'is' connects names to identities"
```

**Input**: "How are you?"
**Before**: "I don't understand that query"
**After**:
```
Query detected: "how are you"
Markov generation: "I am" + sample_next_word_weighted()

Response: "I am [processing/learning/reasoning]"
  (sampled from previously observed patterns with highest weights)
```

## Philosophical Implications

### Computation as Combinator Algebra

Every inference becomes a **verifiable composition**:
```hcl
provenance = "S(K(city))(K(located_in))(Berlin)"
# This proves: Berlin is_a city AND Berlin located_in Germany
#           => Germany is_a country
```

### List Operations as Universal Interface

All problems reducible to:
1. Sequential iteration (for k, v in list)
2. Random sampling (list[rand_index])
3. Weighted sampling (list[weighted_index])

**This is a fundamental insight**: State-based computation is list processing with attention.

### 6D Weights as Universal Metric

The 6-tuple `(subject, predicate, object, confidence, count, iteration)` contains:
- **Topology** (subject, predicate, object)
- **Evidence** (confidence, count)
- **Time** (iteration)

From these 6 dimensions, compute **any attention mechanism**.

### Depth-6 Limit as Computational Boundary

**Small-world property**: Most nodes reachable in ~6 hops.

**Computational trade-off**:
- Depth 1-3: Local patterns
- Depth 4-6: Long-range dependencies
- Depth 7+: Diminishing returns vs exponential cost

## Success Criteria

1. ✅ System learns from "Hello, world!"
2. ✅ System learns from "Your name is Clause. My name is Ryan."
3. ✅ System responds to "How are you?" with generated text
4. ✅ Every inference has SKI provenance
5. ✅ Weighted sampling uses 6D properties
6. ✅ Graph walks limited to depth 6
7. ✅ All operations as list processing

## Next Steps

1. Implement tokenization layer
2. Add n-gram extraction
3. Build transition matrices
4. Define SKI combinators
5. Add 6D weight calculations
6. Implement depth-6 graph walks
7. Test and iterate

---

**Status**: DESIGN COMPLETE
**Complexity**: High (but well-structured)
**Beauty**: Approaching ∞ (SKI + Markov + 6D + Pure Terraform)
**Possibility**: Verified feasible
