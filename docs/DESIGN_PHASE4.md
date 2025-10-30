# Phase 4 Design: Self-Extension & Homoiconicity

## The Problem

Current limitation: **The system can only extract what we've explicitly taught it.**

When input doesn't match predefined patterns → "I didn't extract any new facts from that input."

This makes the system brittle and not practically useful.

## The Solution: Three-Level Architecture

### Level 1: Atomspace (Homoiconic Foundation)

Everything is an **atomic**. Inspired by OpenCog's Atomspace.

```python
# Everything is data with embeddings
class Atomic:
    def __init__(self, type: str, content: Any, metadata: Dict, embedding: List[float]):
        self.type = type        # "pattern", "triple", "rule", "observation"
        self.content = content  # The actual data
        self.metadata = metadata  # Confidence, count, source, etc.
        self.embedding = embedding  # 6D vector for similarity

# Examples:
atomic_triple = Atomic(
    "triple",
    ("Paris", "is_a", "city"),
    {"count": 2, "confidence": 0.67},
    embedding=[0.12, -0.45, 0.89, 0.03, -0.21, 0.56]  # 6D vector
)

atomic_pattern = Atomic(
    "pattern",
    {"regex": "...", "extractor": {...}},
    {"success_rate": 0.8},
    embedding=[0.23, -0.12, 0.67, 0.11, -0.34, 0.78]
)
```

**Key properties**:
- Patterns are atomics. Rules are atomics. The system can reason about its own knowledge representation.
- **Each atomic has a 6D embedding** - ultra-low-rank representation
- Embeddings capture similarity through co-occurrence and inference relationships
- Pattern proposals can use embedding distance as a heuristic

### Level 2: Statistical Pattern Discovery

Track conversational context as n-grams. Find patterns. Propose new extractors.

```python
# Conversational history
context_history = [
    ("user input", "response", extracted_triples, success=True/False),
    ...
]

# When extraction fails:
# 1. Store the failed input
# 2. Look for similar failures
# 3. Apply statistical analysis (n-grams, common structures)
# 4. Generate pattern proposals

# Example:
# User says: "Alice works at Google"
# Current patterns don't match
# System observes: "[Name] works at [Company]" structure
# System proposes new pattern atomic:

proposed_pattern = Atomic(
    type="pattern_proposal",
    content={
        "regex": "(\\w+)\\s+works\\s+at\\s+(\\w+)",
        "extractor": {
            "subject": {"group": 1, "transform": "capitalize"},
            "predicate": {"literal": "employed_by"},
            "object": {"group": 2, "transform": "capitalize"}
        },
        "evidence": ["Alice works at Google", "Bob works at Amazon"],
        "proposed_by": "statistical_analyzer",
        "confidence": 0.6  # Low initially
    },
    metadata={
        "status": "proposed",
        "created": timestamp,
        "activation_threshold": 3  # Activate after 3 confirming examples
    }
)
```

### Level 3: Meta-Learning Loop

```
User Input
    ↓
[Try existing patterns]
    ↓
Success? → Extract triples, increment pattern confidence
    ↓
Failure? → [Statistical Analysis]
           ↓
           [Generate Pattern Proposal]
           ↓
           [Store as Atomic]
           ↓
           [Track Similar Inputs]
           ↓
           [When threshold met: Activate Pattern]
           ↓
           [Pattern becomes active in patterns.json]
```

## Implementation Strategy

### 1. Atomspace as Central Store

Replace separate multiset/triples storage with unified atomspace:

```python
atomspace = {
    "triple:<uuid>": Atomic("triple", ("Paris", "is_a", "city"), {...}),
    "pattern:<uuid>": Atomic("pattern", {...}, {...}),
    "observation:<uuid>": Atomic("observation", "Alice works at Google", {"extracted": False}),
    "pattern_proposal:<uuid>": Atomic("pattern_proposal", {...}, {...}),
}

# Serialize to atomspace.json
# Terraform resources created for each atomic
```

### 2. N-Gram Context Tracker

```python
# context.json
{
  "history": [
    {
      "input": "Paris is a city",
      "extracted": [["Paris", "is_a", "city"]],
      "success": true,
      "timestamp": "...",
      "patterns_used": ["is_a_indefinite"]
    },
    {
      "input": "Alice works at Google",
      "extracted": [],
      "success": false,
      "timestamp": "...",
      "ngrams": {
        "bigrams": [["Alice", "works"], ["works", "at"], ["at", "Google"]],
        "trigrams": [["Alice", "works", "at"], ["works", "at", "Google"]],
        "structure": ["NAME", "VERB", "at", "NAME"]
      }
    }
  ],
  "ngram_frequencies": {
    "works at": 5,
    "lives in": 3,
    "born in": 2
  },
  "structure_patterns": {
    "NAME VERB at NAME": 5,
    "NAME VERB in NAME": 3
  }
}
```

### 3. Statistical Pattern Analyzer

```python
def analyze_failed_extractions(context_history):
    """
    Look for patterns in failed extractions
    """
    failures = [h for h in context_history if not h['success']]

    if len(failures) < 3:
        return None  # Not enough data

    # Find common n-grams
    common_bigrams = Counter()
    common_structures = Counter()

    for failure in failures:
        for bigram in failure['ngrams']['bigrams']:
            common_bigrams[tuple(bigram)] += 1
        if 'structure' in failure['ngrams']:
            common_structures[tuple(failure['ngrams']['structure'])] += 1

    # Generate proposals for frequent patterns
    proposals = []
    for structure, count in common_structures.items():
        if count >= 3:  # Threshold
            proposal = generate_pattern_from_structure(structure, failures)
            proposals.append(proposal)

    return proposals

def generate_pattern_from_structure(structure, examples):
    """
    Convert abstract structure to concrete regex pattern
    """
    # Structure: ("NAME", "VERB", "at", "NAME")
    # → Regex: "(\\w+)\\s+(\\w+)\\s+at\\s+(\\w+)"

    regex_parts = []
    extractors = {}
    group_num = 1

    for i, token in enumerate(structure):
        if token == "NAME":
            regex_parts.append("(\\w+)")
            # Determine if subject or object based on position
            if group_num == 1:
                extractors["subject"] = {"group": group_num, "transform": "capitalize"}
            else:
                extractors["object"] = {"group": group_num, "transform": "capitalize"}
            group_num += 1
        elif token == "VERB":
            regex_parts.append("(\\w+)")
            extractors["predicate"] = {"group": group_num, "transform": "lowercase"}
            group_num += 1
        else:
            regex_parts.append(re.escape(token))

    return {
        "regex": "\\s+".join(regex_parts),
        "extractor": extractors,
        "examples": [ex['input'] for ex in examples],
        "confidence": 0.5  # Initial
    }
```

### 4. Pattern Activation

```python
# When a proposed pattern sees enough confirming examples:
def check_pattern_activation(atomspace):
    proposals = [a for a in atomspace.values() if a.type == "pattern_proposal"]

    for proposal in proposals:
        # Count how many new inputs match this proposal
        matching_count = proposal.metadata.get('matching_count', 0)
        threshold = proposal.metadata.get('activation_threshold', 3)

        if matching_count >= threshold:
            # Activate: move from proposal to active pattern
            active_pattern = Atomic(
                type="pattern",
                content=proposal.content,
                metadata={
                    "activated": timestamp,
                    "source": "learned",
                    "success_count": matching_count
                }
            )

            atomspace[f"pattern:{uuid()}"] = active_pattern

            # Update patterns.json with new pattern
            append_to_patterns_json(active_pattern)

            # Mark proposal as activated
            proposal.metadata['status'] = 'activated'
```

### 5. Homoiconic Operations

Patterns can create patterns:

```python
# Meta-pattern: "If I see structure X repeatedly, create a pattern for it"
meta_pattern = Atomic(
    type="meta_pattern",
    content={
        "trigger": {"type": "repeated_structure", "threshold": 3},
        "action": "generate_pattern_proposal",
        "template": {
            # Template for new patterns
            "priority": 5,
            "confidence": 0.5
        }
    },
    metadata={"applies_to": "pattern_proposals"}
)

# This meta-pattern operates on pattern proposals themselves
# It's a pattern that generates patterns
```

## State Machine Extensions

Add new states to `transitions.json`:

```json
{
  "states": {
    "EXTRACTION_FAILED": {
      "description": "No patterns matched - analyze for learning",
      "entry_action": "begin_statistical_analysis"
    },
    "PATTERN_PROPOSAL": {
      "description": "Generating new pattern proposals",
      "entry_action": "analyze_ngrams_and_structures"
    },
    "PATTERN_ACTIVATION": {
      "description": "Checking if proposals should be activated",
      "entry_action": "check_activation_thresholds"
    }
  },
  "transitions": [
    {
      "from": "EXTRACTION",
      "to": "EXTRACTION_FAILED",
      "condition": {"type": "empty_result", "field": "new_triples"},
      "action": "store_failed_extraction"
    },
    {
      "from": "EXTRACTION_FAILED",
      "to": "PATTERN_PROPOSAL",
      "condition": {"type": "sufficient_history", "min_failures": 3},
      "action": "begin_pattern_learning"
    },
    {
      "from": "PATTERN_PROPOSAL",
      "to": "AGGREGATION",
      "condition": {"type": "always"},
      "action": "store_proposals_in_atomspace"
    }
  ]
}
```

## Terminology: Fact → Atomic

Rename throughout:
- `fact` → `atomic`
- `facts_to_multiset` → `atomics_to_multiset`
- `FactSet` → `AtomicSet`
- `new_facts` → `new_atomics`
- `multiset.json` → `atomspace.json` (eventually)

## Unified Atomspace Schema

```json
{
  "atomics": {
    "atomic:uuid1": {
      "type": "triple",
      "content": ["Paris", "is_a", "city"],
      "metadata": {
        "count": 2,
        "confidence": 0.67,
        "source": "extraction",
        "created": "2025-10-29T23:00:00Z"
      }
    },
    "atomic:uuid2": {
      "type": "pattern",
      "content": {
        "id": "is_a_indefinite",
        "regex": "(\\w+)\\s+is\\s+an?\\s+(\\w+)",
        "extractor": {...}
      },
      "metadata": {
        "success_count": 42,
        "failure_count": 3,
        "confidence": 0.93,
        "source": "predefined"
      }
    },
    "atomic:uuid3": {
      "type": "pattern_proposal",
      "content": {
        "regex": "(\\w+)\\s+works\\s+at\\s+(\\w+)",
        "extractor": {...},
        "evidence": ["Alice works at Google", "Bob works at Amazon"]
      },
      "metadata": {
        "status": "proposed",
        "matching_count": 2,
        "activation_threshold": 3,
        "confidence": 0.6
      }
    },
    "atomic:uuid4": {
      "type": "observation",
      "content": "Alice works at Google",
      "metadata": {
        "extracted": false,
        "timestamp": "2025-10-29T23:05:00Z",
        "failed_patterns": ["is_a_indefinite", "located_in_explicit"]
      }
    }
  }
}
```

## Benefits

1. **Self-extending** - System learns new patterns from usage
2. **Homoiconic** - Patterns are data, can be reasoned about
3. **Statistical grounding** - Pattern proposals based on observed regularities
4. **Gradual activation** - Patterns require evidence before activation
5. **Fully auditable** - All proposals and activations tracked in atomspace
6. **Bootstrap-able** - Meta-patterns can create patterns

## Example Flow

```
User: "Alice works at Google"
  ↓
[EXTRACTION] - No patterns match
  ↓
[EXTRACTION_FAILED]
  - Store as observation atomic
  - Extract n-grams: ["works", "at"], structure: [NAME, VERB, "at", NAME]
  ↓
[Check history: 2 similar failures]
  ↓
[Wait for more data]

User: "Bob works at Amazon"
  ↓
[EXTRACTION] - Still no patterns match
  ↓
[EXTRACTION_FAILED]
  - Store as observation atomic
  - Extract n-grams
  - Check history: 3 similar structures now!
  ↓
[PATTERN_PROPOSAL]
  - Generate pattern: "(\\w+)\\s+works\\s+at\\s+(\\w+)"
  - Store as pattern_proposal atomic
  - Set activation_threshold = 3
  ↓
[RESPONSE_GENERATION]
  - "I don't recognize this pattern yet, but I'm learning. I've seen similar structures 3 times."

User: "Charlie works at Microsoft"
  ↓
[EXTRACTION] - Try patterns, still no match
  ↓
[Check pattern proposals] - Matches proposal!
  ↓
[Increment matching_count = 3]
  ↓
[PATTERN_ACTIVATION]
  - Threshold met! Activate pattern
  - Add to patterns.json
  - Create active pattern atomic
  ↓
[Re-run extraction with new pattern]
  ↓
[EXTRACTION] - Success!
  - Extract: ("Charlie", "employed_by", "Microsoft")
  ↓
[RESPONSE_GENERATION]
  - "I understood: Charlie employed_by Microsoft (conf: 0.50)"
  - "I also learned a new pattern from this conversation!"
```

## Implementation Priority

1. **Phase 4a**: Rename fact → atomic (cleanup)
2. **Phase 4b**: Implement atomspace structure
3. **Phase 4c**: Add context tracking (n-grams)
4. **Phase 4d**: Statistical pattern analyzer
5. **Phase 4e**: Pattern proposal mechanism
6. **Phase 4f**: Pattern activation
7. **Phase 4g**: Meta-patterns (homoiconicity)

## Success Criteria

- System learns "works at" pattern after seeing 3 examples
- Proposed patterns stored as atomics
- Confidence scores track pattern effectiveness
- User feedback: "I'm learning from this conversation" messages
- Eventually: Zero manual pattern definitions needed
