# Atomic Embeddings: 6D Similarity Space

## Core Idea

Each atomic has a **6-dimensional embedding vector** - a ultra-low-rank approximation of relationships.

## Why 6 Dimensions?

- **Lightweight**: 6 floats = 24 bytes per atomic
- **Sufficient**: Can capture essential relationships without overfitting
- **Interpretable**: Low enough to potentially understand what each dimension represents
- **Fast**: Cosine similarity in 6D is trivial to compute

## Embedding Updates

### Co-occurrence Learning

When atomics appear together, their embeddings should converge:

```python
def update_embeddings_cooccurrence(atomic1, atomic2, learning_rate=0.1):
    """
    If atomics co-occur in same context, pull embeddings closer
    """
    # Direction from atomic1 to atomic2
    diff = atomic2.embedding - atomic1.embedding

    # Move atomic1 toward atomic2
    atomic1.embedding += learning_rate * diff
    atomic2.embedding -= learning_rate * diff  # Symmetric
```

**Example:**
- "Paris" and "France" appear in same sentence → embeddings converge
- "London" and "England" appear in same sentence → embeddings converge
- If "Paris" ≈ "London", then "France" ≈ "England" should emerge

### Inference-Based Learning

When inference creates new atomics, update embeddings:

```python
def update_embeddings_inference(premise_atomics, conclusion_atomic, strength=0.2):
    """
    If premises → conclusion, conclusion embedding should be influenced by premises
    """
    # Average premise embeddings
    avg_premise = np.mean([a.embedding for a in premise_atomics], axis=0)

    # Pull conclusion toward average of premises
    conclusion_atomic.embedding += strength * (avg_premise - conclusion_atomic.embedding)
```

**Example:**
- `(Paris, is_a, city) ∧ (Paris, located_in, France) → (France, is_a, country)`
- France's embedding influenced by Paris and city

### Pattern Success Learning

When a pattern successfully extracts, strengthen pattern-atomic affinity:

```python
def update_pattern_embedding(pattern_atomic, extracted_atomics, success=True):
    """
    Successful patterns should have embeddings similar to what they extract
    """
    if success:
        for atomic in extracted_atomics:
            # Pull pattern embedding toward successful extractions
            diff = atomic.embedding - pattern_atomic.embedding
            pattern_atomic.embedding += 0.05 * diff
```

## Using Embeddings for Pattern Proposals

### Similarity-Based Generalization

When we see an unmatched input, find atomics with similar embeddings:

```python
def propose_pattern_from_similarity(failed_input, atomspace):
    """
    Use embedding similarity to generalize from known patterns
    """
    # Extract entities from failed input (simple heuristic)
    entities = extract_capitalized_words(failed_input)

    # Find atomics with similar embeddings in atomspace
    similar_atomics = []
    for entity_str in entities:
        # Find atomic in atomspace
        entity_atomic = find_atomic_by_content(entity_str, atomspace)
        if entity_atomic:
            # Find k-nearest neighbors in embedding space
            neighbors = find_knn(entity_atomic.embedding, atomspace, k=5)
            similar_atomics.extend(neighbors)

    # Look at successful patterns used on similar atomics
    successful_patterns = [
        a for a in similar_atomics
        if a.type == "pattern" and a.metadata.get('success_count', 0) > 3
    ]

    # Adapt most similar pattern
    if successful_patterns:
        best_pattern = max(successful_patterns,
                          key=lambda p: cosine_similarity(p.embedding, entity_atomic.embedding))

        # Clone and adapt pattern
        new_pattern = adapt_pattern(best_pattern, failed_input)
        return new_pattern
```

### Example Flow

```
User: "Alice works at Google"
  ↓
[No patterns match]
  ↓
[Extract entities: "Alice", "Google"]
  ↓
[Find Alice embedding - doesn't exist, initialize randomly]
[Find Google embedding - doesn't exist, initialize randomly]
  ↓
[Look for similar embeddings:]
  - "Paris" has embedding [0.12, -0.45, 0.89, ...]
  - "France" has embedding [0.15, -0.42, 0.91, ...]
  - These are close to "Alice" and "Google" (cities/places/entities)
  ↓
[Find patterns that worked on Paris/France:]
  - "located_in" pattern: "(\\w+)\\s+(?:in|located\\s+in)\\s+(\\w+)"
  - This pattern has high success_count
  ↓
[Adapt pattern for "works at":]
  - New pattern: "(\\w+)\\s+works\\s+at\\s+(\\w+)"
  - Predicate: "employed_by" (adapted from "located_in")
  - Store as pattern_proposal with low initial confidence
```

## Initialization

### Random Initialization
New atomics get random embeddings from unit sphere:
```python
def init_embedding():
    vec = np.random.randn(6)
    return vec / np.linalg.norm(vec)  # Normalize to unit sphere
```

### Semantic Initialization (Future)
Could initialize based on string similarity:
```python
def init_embedding_semantic(content_str):
    # Simple character n-gram hash
    ngrams = [content_str[i:i+3] for i in range(len(content_str)-2)]
    # Hash to 6D space
    embedding = hash_to_6d(ngrams)
    return embedding / np.linalg.norm(embedding)
```

## Embedding Space Properties

After sufficient training, we expect:

**Dimension 0**: Entity type (person, place, thing)
**Dimension 1**: Abstractness (concrete ↔ abstract)
**Dimension 2**: Relationship type (physical, social, logical)
**Dimension 3**: Scope (local ↔ global)
**Dimension 4**: Temporal (static ↔ dynamic)
**Dimension 5**: Confidence/certainty

These emerge naturally from co-occurrence and inference patterns.

## Storage

```json
{
  "atomics": {
    "atomic:uuid1": {
      "type": "triple",
      "content": ["Paris", "is_a", "city"],
      "metadata": {"count": 2, "confidence": 0.67},
      "embedding": [0.12, -0.45, 0.89, 0.03, -0.21, 0.56]
    }
  }
}
```

Only 24 extra bytes per atomic!

## Benefits

1. **Pattern proposals from similarity** - If London ≈ Paris and London's patterns work, try them on Paris
2. **Generalization** - Learn that "works at" is like "located in"
3. **Confidence estimation** - Embeddings far from known space → low confidence
4. **Clustering** - Group similar atomics for batch operations
5. **Visualization** - Project 6D → 2D for debugging (t-SNE)

## Implementation

Phase 4 will add:
1. Embedding field to Atomic class
2. Initialization logic (random unit sphere)
3. Co-occurrence updates after each iteration
4. Inference-based updates
5. Similarity search in atomspace
6. Pattern proposal from k-NN embeddings

## Example After Training

```
Paris:    [0.12, -0.45, 0.89, 0.03, -0.21, 0.56]
London:   [0.14, -0.43, 0.91, 0.05, -0.19, 0.54]  # Close!
France:   [0.15, -0.42, 0.91, 0.04, -0.20, 0.55]  # Close to Paris/London
Google:   [-0.34, 0.21, -0.12, 0.45, 0.33, -0.67]  # Different cluster
Microsoft: [-0.32, 0.23, -0.14, 0.43, 0.31, -0.65]  # Close to Google

# Pattern embeddings
"located_in":  [0.13, -0.44, 0.90, 0.04, -0.20, 0.55]  # Near Paris/France
"employed_by": [-0.33, 0.22, -0.13, 0.44, 0.32, -0.66]  # Near Google/Microsoft
```

**Observation**: Place-related atomics cluster together. Company-related atomics cluster together. Patterns cluster near what they extract!

## Future: Meta-Learning on Embeddings

Eventually, learn to **predict** good embeddings for new atomics:

```python
def predict_embedding(atomic_content, context_atomics):
    """
    Use context to predict good initial embedding
    """
    # Average embeddings of context
    context_avg = np.mean([a.embedding for a in context_atomics], axis=0)

    # Add small random perturbation
    noise = np.random.randn(6) * 0.1

    return normalize(context_avg + noise)
```

This bootstraps new atomics with sensible starting points.
