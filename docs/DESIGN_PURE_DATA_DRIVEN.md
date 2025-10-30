# Pure Data-Driven Architecture

## Core Principle

**ALL logic must emerge from data, NOT be hardcoded.**

## What We CANNOT Do

❌ Hardcoded regex patterns:
```hcl
# WRONG
regex("^(\\w+)\\s+is\\s+a\\s+(\\w+)$", input)  # "X is a Y" baked in
```

❌ Hardcoded query detection:
```hcl
# WRONG
is_query = can(regex("^(what|where|who)", input))  # Natural language baked in
```

❌ Hardcoded inference rules:
```hcl
# WRONG
if v.predicate == "located_in" && type == "city"  # Semantic meaning baked in
```

❌ Inline natural language:
```hcl
# WRONG
object = "country"  # Concept baked in
```

## What We CAN Do

✅ Pure tokenization:
```hcl
tokens = split(" ", lower(input))
```

✅ N-gram extraction (statistical only):
```hcl
bigrams = {
  for i in range(length(tokens) - 1) :
  "${tokens[i]}_${tokens[i+1]}" => {
    left = tokens[i]
    right = tokens[i+1]
  }
}
```

✅ Graph operations (structure only):
```hcl
neighbors = {
  for triple in all_triples :
  triple.subject => triple.object
}
```

✅ SKI combinators (pure functions):
```hcl
combinator_I = { apply = "lambda x: x" }
combinator_K = { apply = "lambda x: lambda y: x" }
combinator_S = { apply = "lambda f: lambda g: lambda x: f(x)(g(x))" }
```

✅ Weighted sampling from lists:
```hcl
sample_index = weighted_pick(weights, random_seed)
```

✅ Depth-limited walks:
```hcl
reachable = bfs(start_node, max_depth=6, adjacency)
```

## Architecture

### Layer 1: Pure Tokenization
```
Input: "Hello world"
→ Tokens: ["hello", "world"]
```

No semantic understanding. Just split on whitespace.

### Layer 2: N-gram Extraction
```
Tokens: ["hello", "world"]
→ Bigrams: [(hello, world)]
→ Store as triple: (hello, follows, world)
```

"follows" is the ONLY predicate we introduce. It means "appears before in sequence."

### Layer 3: State Accumulation
```
Iteration 1: "Hello world"
  State: {(hello, follows, world): count=1}

Iteration 2: "Hello friend"
  State: {(hello, follows, world): count=1, (hello, follows, friend): count=1}

Iteration 3: "Hello world"
  State: {(hello, follows, world): count=2, (hello, follows, friend): count=1}
```

Patterns emerge from frequency.

### Layer 4: Transition Matrices
```
transitions["hello"] = ["world": 0.67, "friend": 0.33]
```

Markov chain probabilities computed from counts.

### Layer 5: Graph Structure
```
adjacency = {
  "hello": ["world", "friend"],
  "world": [],
  "friend": []
}

degrees = {
  "hello": 2,
  "world": 0,
  "friend": 0
}
```

Pure graph metrics. No semantic labels.

### Layer 6: SKI Combinators

Define three primitive operations:

**I (Identity)**: Pass data through unchanged
```hcl
apply_I = lambda data: data
```

**K (Constant)**: Filter/select data
```hcl
apply_K = lambda pattern: lambda data:
  [item for item in data if matches(item, pattern)]
```

**S (Substitution)**: Compose operations
```hcl
apply_S = lambda f: lambda g: lambda data:
  f(data)(g(data))
```

ALL inference expressed as SKI compositions.

### Layer 7: Graph Inference (SKI-driven)

**Pass 1: I (Identity)** - No transformation
```hcl
pass1 = apply_I(all_triples)
# Just returns all_triples unchanged
```

**Pass 2: K (Select)** - Filter by property
```hcl
pass2 = apply_K("high_degree")(nodes)
# Returns nodes where degree > threshold
```

**Pass 3: S (Compose)** - Combine operations
```hcl
pass3 = apply_S(find_neighbors)(calculate_weight)(node)
# For each node, find neighbors AND calculate weights, then combine
```

**Pass 4: Random Walk** - Sample from weighted list
```hcl
pass4 = sample_from(nodes, weights, random_seed)
```

### Layer 8: 6D Weights

Each triple has 6 properties:
1. subject (string)
2. predicate (string)
3. object (string)
4. confidence (float) - from frequency
5. count (int) - observations
6. iteration (int) - recency

**Weight formula:**
```hcl
weight = confidence * log(count + 1) * exp(-(current_iter - iteration) * decay_rate)
```

This is PURE MATH. No hardcoded meanings.

### Layer 9: Depth-Limited Walks

Explore graph up to depth 6:

```hcl
# BFS from node
reachable_depth_6 = {
  for start in nodes :
  start => explore_bfs(start, max_depth=6, adjacency)
}

# DFS with backtracking
paths_depth_6 = {
  for start in nodes :
  start => explore_dfs(start, max_depth=6, adjacency)
}
```

Computes **influence scores**: how many paths exist between nodes within 6 hops.

### Layer 10: Response Generation

**NOT** hardcoded templates. Instead:

```hcl
# Sample next word based on transition probabilities
response_tokens = []
current = last_input_token

for i in range(max_length):
  next_candidates = transitions[current]
  weights = [probs[word] for word in next_candidates]
  next = weighted_sample(next_candidates, weights, seed=iteration+i)
  response_tokens.append(next)
  current = next

response = join(" ", response_tokens)
```

Pure Markov text generation.

## How Patterns Emerge

### Example: Learning "is_a" Relationship

**NOT** hardcoded as regex.

**Instead:**

```
Iteration 1: "Berlin is a city"
  Triples: (Berlin, follows, is), (is, follows, a), (a, follows, city)

Iteration 2: "Paris is a city"
  Triples: (Berlin, follows, is), (is, follows, a), (a, follows, city) [count=2],
           (Paris, follows, is), ...

Iteration 3: "Tokyo is a city"
  Pattern emerges: [Entity, is, a, Type] is frequent sequence
```

After many observations, the system learns:
- Token "is" often precedes "a"
- Token "a" often precedes type labels (city, country, etc.)
- This 3-word sequence indicates a relationship

**The system discovers the "is_a" pattern statistically, not from hardcoded rules.**

### Example: Query Detection

**NOT** hardcoded as `regex("^(what|where|who)")`.

**Instead:**

```
Iteration 1: "What is Berlin?"
  Triples: (what, follows, is), (is, follows, berlin)

Iteration 2: "Where is Paris?"
  Triples: (where, follows, is), (is, follows, paris)

After many iterations:
  - "what" and "where" have high degree (connect to many words)
  - They frequently appear at start of sequence (no predecessors)
  - Sentences starting with them tend to be shorter
  - User waits longer for response (signals expectation)

Pattern emerges: high-degree words at sequence start = likely query
```

**Query detection emerges from statistical properties, not hardcoded.**

## Data Storage

ALL patterns stored AS DATA in terraform.tfstate:

```json
{
  "resources": [
    {
      "type": "terraform_data",
      "name": "triple",
      "instances": [
        {
          "attributes": {
            "input": {
              "subject": "hello",
              "predicate": "follows",
              "object": "world",
              "confidence": 0.85,
              "count": 5,
              "iteration": 10
            }
          }
        }
      ]
    }
  ]
}
```

NOT:
```hcl
# WRONG - pattern in code
is_a_pattern = "X is a Y"
```

## SKI Provenance

Each inference tagged with SKI composition that generated it:

```json
{
  "subject": "France",
  "predicate": "high_degree",
  "object": "hub",
  "combinator": "K(degree > avg)",
  "pass": 2
}
```

This proves: "France labeled as hub because K combinator selected it based on degree > average."

**Verifiable, inspectable reasoning.**

## Implementation Strategy

1. **Remove all hardcoded patterns** - Delete regex for "X is a Y", etc.
2. **Tokenize everything** - Pure split on whitespace
3. **Extract only bigrams/trigrams** - Pure n-gram statistics
4. **Store as "follows" triples** - Single predicate type
5. **Build transition matrices** - From follow relationships
6. **Implement SKI as pure ops** - I/K/S operate on lists
7. **Graph inference via SKI** - Each pass is SKI composition
8. **6D weights** - Pure formula from properties
9. **Depth-6 walks** - BFS/DFS with depth limit
10. **Markov generation** - Sample from transitions

## Success Criteria

✅ Input "Hello world" → learns (hello, follows, world)
✅ Input "Hello friend" → learns (hello, follows, friend)
✅ Input "Hello" → generates "world" or "friend" (weighted by frequency)
✅ NO hardcoded semantics anywhere
✅ ALL patterns in state, NOT code
✅ SKI provenance for all inferences
✅ Pure graph operations
✅ Patterns emerge statistically

## Philosophy

**Traditional NLP**: Hardcode grammar, semantics, patterns.
**Clause**: Start from zero, learn everything from raw tokens.

**Traditional AI**: Train on corpus, freeze weights.
**Clause**: Continuously learn from every input, never freeze.

**Traditional IaC**: Declare desired state once.
**Clause**: State evolves recursively, never converges.

---

**Status**: Design complete, ready to implement
**Purity**: 100% data-driven
**Hardcoded patterns**: 0
**Learning**: Continuous
