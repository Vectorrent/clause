# Phase 4 Status: In Progress

## Completed

### ✅ Terminology: Fact → Atomic
- Renamed throughout codebase (process.py, main.tf)
- Updated all function names, variables, outputs
- Phase indicator: "4-self-extension"
- Architecture: "homoiconic-atomspace"

### ✅ Design Documents
- **DESIGN_PHASE4.md** - Three-level architecture for self-extension
  - Level 1: Atomspace (homoiconic foundation)
  - Level 2: Statistical pattern discovery (n-grams)
  - Level 3: Meta-learning loop
- **DESIGN_EMBEDDINGS.md** - 6D embedding system
  - Ultra-low-rank representation (6 floats per atomic)
  - Co-occurrence learning
  - Inference-based updates
  - Similarity-based pattern proposals

## Current Bug

**Issue**: Multiset is empty after extraction
- Triples are extracted correctly: `[["Paris", "is_a", "city"]]`
- Atomics are generated: `["Paris is_a city"]`
- But multiset serializes as: `{}`
- Response incorrectly says: "I didn't extract any new atomics"

**Root cause**: State machine action flow issue
- merge_new_facts_action might not be called
- or multiset isn't being set in context correctly
- Need to debug state transitions

## Next Steps (In Order)

### 1. Fix Multiset Bug (Priority 1)
- Debug state machine flow
- Ensure AGGREGATION state is reached
- Verify merge_new_facts_action is called
- Check multiset context propagation

### 2. Implement Atomic Class with Embeddings
```python
class Atomic:
    def __init__(self, type, content, metadata, embedding=None):
        self.type = type  # "triple", "pattern", "rule", "observation"
        self.content = content
        self.metadata = metadata
        self.embedding = embedding or init_random_embedding_6d()

    def to_dict(self):
        return {
            "type": self.type,
            "content": self.content,
            "metadata": self.metadata,
            "embedding": self.embedding.tolist()
        }
```

### 3. Implement Atomspace Storage
- Replace multiset.json and triples.json with atomspace.json
- Unified storage: all atomics in one place
- Each atomic has UUID key
- Embeddings stored per atomic

### 4. Context Tracking (N-Grams)
- Track conversational history
- Extract n-grams from failed extractions
- Store as context.json
- Analyze for structural patterns

### 5. Statistical Pattern Analyzer
- Find common structures in failures
- Generate pattern proposals
- Store proposals as atomics with type="pattern_proposal"

### 6. Embedding Updates
- Co-occurrence: atomics that appear together → similar embeddings
- Inference: derived atomics influenced by premises
- Pattern success: successful patterns → similar to extracted atomics

### 7. Pattern Proposal from Similarity
- When extraction fails, find similar atomics by embedding
- Look at successful patterns on similar atomics
- Adapt pattern for current input
- Store as pattern_proposal atomic

### 8. Pattern Activation
- Track matching count for proposals
- When threshold met (e.g., 3 matches), activate
- Add to patterns.json
- Convert from proposal to active pattern atomic

## Key Insight from User

**6D Embeddings as Lightweight Similarity Space**

Each atomic gets 6 floats - ultra-low-rank approximation of relationships. This enables:
- Generalization without explicit rules
- Pattern proposals from similarity
- Intuition building through co-occurrence
- Only 24 bytes overhead per atomic

Think of it as a tiny neural network representation - enough to capture essential relationships without overfitting.

## Architecture Vision

```
User: "Alice works at Google"
  ↓
[No patterns match] → Store as observation atomic
  ↓
[Similar failures accumulate: 3 times]
  ↓
[Statistical analyzer]: "works at" structure detected
  ↓
[Find similar atomics by embedding]:
  - "Paris" and "London" (places)
  - Their "located_in" pattern worked well
  ↓
[Propose adapted pattern]:
  - "(\\w+)\\s+works\\s+at\\s+(\\w+)"
  - Predicate: "employed_by"
  - Store as pattern_proposal atomic
  ↓
[User: "Bob works at Microsoft"]
  ↓
[Proposal matches!] → Increment matching_count = 3
  ↓
[Activate pattern] → Add to patterns.json
  ↓
[Extract successfully]: ("Bob", "employed_by", "Microsoft")
  ↓
[Response]: "I understood: Bob employed_by Microsoft"
             "I also learned a new pattern!"
```

## Files

### Core
- `terraform/process.py` - Interpreter (needs bug fix)
- `terraform/main.tf` - State management (updated for atomics)
- `terraform/patterns.json` - Pattern specs
- `terraform/operations.json` - Inference rules
- `terraform/transitions.json` - State machine (needs EXTRACTION_FAILED state)

### Design
- `DESIGN_PHASE4.md` - Overall architecture
- `DESIGN_EMBEDDINGS.md` - 6D embedding system
- `STATUS_PHASE4.md` - This file

### To Create
- `terraform/atomspace.json` - Unified atomic storage
- `terraform/context.json` - Conversational history
- `terraform/embeddings.py` - Embedding utilities

## Testing Once Bug Fixed

```bash
# Test basic extraction
terraform apply -var='user_input=Paris is a city' -var='iteration=1'
# Should see multiset: {"Paris is_a city": 1}

# Test inference
terraform apply -var='user_input=Paris is in France' -var='iteration=2'
# Should see derived atomic: "France is_a country"

# Test unknown pattern (should store as observation)
terraform apply -var='user_input=Alice works at Google' -var='iteration=3'
# Should see: "I don't recognize this pattern yet" + observation stored

# Repeat 3 times, should propose pattern
# On 4th time, pattern should activate and extract successfully
```

## Philosophy

**The system must learn from failures.**

Current system: failure → "I didn't extract anything" → nothing learned

Phase 4 system: failure → observation atomic → statistical analysis → pattern proposal → eventual success

The embeddings provide the "intuition" to generalize from known patterns to new situations.

## Timeline Estimate

- Fix bug: 30 min
- Atomic class + embeddings: 1 hour
- Atomspace storage: 1 hour
- Context tracking: 2 hours
- Statistical analyzer: 3 hours
- Pattern proposals: 3 hours
- Embedding updates: 2 hours
- Pattern activation: 1 hour

**Total**: ~13 hours of focused work

## Current Status

**Phase 3**: Complete ✅
**Phase 4**: In progress (bug blocking, design complete)
**Next session**: Fix multiset bug, then implement Atomic class

---

**Sleep well! The system is close to self-extension.** 🚀
