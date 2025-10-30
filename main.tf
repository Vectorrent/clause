# ============================================================================
# PURE DATA-DRIVEN COMPUTATIONAL SPAGHETTI
# No hardcoded patterns. No semantic rules. Pure statistical learning.
# All patterns emerge from data. Maximum expressivity through recurrent
# attention over all data. Never converge. Stay at the edge of chaos.
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

# ============================================================================
# Inputs: The external signal
# ============================================================================

variable "iteration" {
  type    = number
  default = 0
}

variable "user_input" {
  type    = string
  default = ""
}

# ============================================================================
# Self-Reference: Read our own consciousness
# ============================================================================

locals {
  state_file      = "${path.module}/terraform.tfstate"
  prev_state_raw  = fileexists(local.state_file) ? file(local.state_file) : "{}"
  prev_state      = try(jsondecode(local.prev_state_raw), null)

  # Extract ALL atomics from previous state (attend to everything)
  prev_atomics_raw = local.prev_state != null ? flatten([
    for res in try(local.prev_state.resources, []) : [
      for inst in try(res.instances, []) : {
        key   = try(inst.index_key, "")
        count = try(inst.attributes.input.value.count, 0)
        conf  = try(inst.attributes.input.value.confidence, 0)
        iter  = try(inst.attributes.input.value.iteration, 0)
      }
      if res.type == "terraform_data" && res.name == "atomic"
    ]
  ]) : []

  prev_atomics = {
    for item in local.prev_atomics_raw : item.key => {
      count      = item.count
      confidence = item.conf
      iteration  = item.iter
    }
    if item.key != ""
  }

  # Extract ALL triples (attend to everything)
  prev_triples_raw = local.prev_state != null ? flatten([
    for res in try(local.prev_state.resources, []) : [
      for inst in try(res.instances, []) : {
        key = try(inst.index_key, "")
        s   = try(inst.attributes.input.value.subject, "")
        p   = try(inst.attributes.input.value.predicate, "")
        o   = try(inst.attributes.input.value.object, "")
      }
      if res.type == "terraform_data" && res.name == "triple"
    ]
  ]) : []

  prev_triples = {
    for item in local.prev_triples_raw : item.key => {
      subject   = item.s
      predicate = item.p
      object    = item.o
    }
    if item.key != "" && item.s != ""
  }
}

# ============================================================================
# Pure Tokenization: No semantic extraction, just raw tokens
# ============================================================================

locals {
  # Clean input: remove punctuation, lowercase
  input_cleaned = lower(replace(replace(replace(replace(replace(
    var.user_input,
    "!", ""), "?", ""), ".", ""), ",", ""), "  ", " "))

  # Tokenize: split into words
  tokens_raw = split(" ", local.input_cleaned)
  tokens = [for w in local.tokens_raw : w if w != ""]

  # Token count for statistics
  token_count = length(local.tokens)
}

# ============================================================================
# N-gram Extraction: Pure statistical patterns
# ============================================================================

locals {
  # Extract bigrams (word pairs) - ONLY pattern we extract
  bigrams = local.token_count >= 2 ? {
    for i in range(local.token_count - 1) :
    "${local.tokens[i]}_follows_${local.tokens[i+1]}_iter${var.iteration}" => {
      subject   = local.tokens[i]
      predicate = "follows"  # ONLY predicate - means "precedes in sequence"
      object    = local.tokens[i+1]
      iteration = var.iteration
    }
  } : {}

  # Extract trigrams for richer context
  trigrams = local.token_count >= 3 ? {
    for i in range(local.token_count - 2) :
    "${local.tokens[i]}_${local.tokens[i+1]}_leads_${local.tokens[i+2]}_iter${var.iteration}" => {
      subject   = "${local.tokens[i]}_${local.tokens[i+1]}"  # Compound subject
      predicate = "leads_to"
      object    = local.tokens[i+2]
      iteration = var.iteration
    }
  } : {}

  # Merge all n-grams
  new_triples_from_input = merge(local.bigrams, local.trigrams)
}

# ============================================================================
# Transition Matrices: Markov chain from observed sequences
# ============================================================================

locals {
  # Merge previous + new triples
  all_triples = merge(local.prev_triples, local.new_triples_from_input)

  # Extract ALL "follows" relationships from state
  follow_edges = [
    for k, v in local.all_triples : {
      from = v.subject
      to   = v.object
    }
    if v.predicate == "follows"
  ]

  # Build transition lists: word → [list of words that follow it]
  transition_lists_raw = {
    for edge in local.follow_edges :
    edge.from => edge.to...
  }

  # Deduplicate and count
  transition_lists = {
    for word, followers_list in local.transition_lists_raw :
    word => distinct(followers_list)
  }

  # Calculate probabilities: P(next_word | current_word)
  transition_probs = {
    for word, followers in local.transition_lists :
    word => {
      for follower in followers :
      follower => (
        length([
          for edge in local.follow_edges :
          edge.to if edge.from == word && edge.to == follower
        ]) / max(length([
          for edge in local.follow_edges :
          edge.to if edge.from == word
        ]), 1)
      )
    }
  }
}

# ============================================================================
# SKI Combinator Calculus: Pure functional abstractions
# ============================================================================

locals {
  # I combinator: Identity
  combinator_I = {
    type      = "I"
    operation = "identity"
    formula   = "λx.x"
  }

  # K combinator: Constant selector
  combinator_K = {
    type      = "K"
    operation = "select_first"
    formula   = "λx.λy.x"
  }

  # S combinator: Substitution / Application
  combinator_S = {
    type      = "S"
    operation = "apply_combine"
    formula   = "λf.λg.λx.f(x)(g(x))"
  }
}

# ============================================================================
# Graph Structure: Pure topology, no semantics
# ============================================================================

locals {
  # Adjacency: node → [neighbors]
  adjacency = {
    for node in distinct([for k, v in local.all_triples : v.subject]) :
    node => distinct([
      for k, v in local.all_triples :
      v.object
      if v.subject == node
    ])
  }

  # Degrees: node → connection count
  degrees = {
    for node, neighbors in local.adjacency :
    node => length(neighbors)
  }

  # Reverse adjacency: node → [predecessors]
  reverse_adjacency = {
    for node in distinct([for k, v in local.all_triples : v.object]) :
    node => distinct([
      for k, v in local.all_triples :
      v.subject
      if v.object == node
    ])
  }

  # In-degrees
  in_degrees = {
    for node, predecessors in local.reverse_adjacency :
    node => length(predecessors)
  }
}

# ============================================================================
# 6D Weight Calculations: Attention from all properties
# ============================================================================

locals {
  # Temporal decay rate
  decay_rate = 0.01

  # Calculate weight for each atomic (using linear decay instead of exp)
  atomic_weights = {
    for atomic_key, props in local.prev_atomics :
    atomic_key => (
      props.confidence *
      log(props.count + 1, 2) *
      max(1 - ((var.iteration - props.iteration) * local.decay_rate), 0.001)
    )
  }

  # Normalize weights
  total_weight = length(local.atomic_weights) > 0 ? sum([
    for k, w in local.atomic_weights : w
  ]) : 1

  normalized_weights = {
    for k, w in local.atomic_weights :
    k => w / local.total_weight
  }

  # Node weights (from in-degree + out-degree)
  node_weights = {
    for node in keys(local.adjacency) :
    node => (
      lookup(local.degrees, node, 0) +
      lookup(local.in_degrees, node, 0)
    )
  }

  # Normalize node weights
  total_node_weight = length(local.node_weights) > 0 ? sum([
    for k, w in local.node_weights : w
  ]) : 1

  normalized_node_weights = {
    for k, w in local.node_weights :
    k => max(w / local.total_node_weight, 0.001)
  }
}

# ============================================================================
# Inference via SKI: Pure graph operations
# ============================================================================

locals {
  # Pass 1: I (Identity) - Attend to ALL nodes
  inferred_pass1_I = {
    for node in keys(local.adjacency) :
    "${node}_observed_iter${var.iteration}_pass1" => {
      subject    = node
      predicate  = "observed"
      object     = "pass1"
      iteration  = var.iteration
      inferred   = true
      combinator = "I"  # Identity: just observe
      pass       = 1
    }
  }

  # Pass 2: K (Select) - Filter high-degree nodes
  avg_degree = length(local.degrees) > 0 ? (
    sum([for k, d in local.degrees : d]) / length(local.degrees)
  ) : 0

  inferred_pass2_K = {
    for node, degree in local.degrees :
    "${node}_hub_iter${var.iteration}_pass2" => {
      subject    = node
      predicate  = "hub"
      object     = "high_degree"
      iteration  = var.iteration
      inferred   = true
      combinator = "K(degree > avg)"  # Constant selector
      pass       = 2
    }
    if degree > local.avg_degree
  }

  # Pass 3: S (Compose) - Explore neighborhoods
  inferred_pass3_S = length(local.adjacency) > 0 ? merge([
    for node, neighbors in local.adjacency : {
      for neighbor in neighbors :
      "${node}_connects_${neighbor}_iter${var.iteration}_pass3" => {
        subject    = node
        predicate  = "connects"
        object     = neighbor
        iteration  = var.iteration
        inferred   = true
        combinator = "S(neighbors)(weight)"  # Apply and combine
        pass       = 3
      }
      if length(neighbors) > 0
    }
  ]...) : {}

  # Pass 4: Weighted Random Walk
  random_node_idx = length(keys(local.adjacency)) > 0 ? (
    var.iteration % length(keys(local.adjacency))
  ) : 0
  random_node = length(keys(local.adjacency)) > 0 ? (
    element(keys(local.adjacency), local.random_node_idx)
  ) : null

  inferred_pass4_random = local.random_node != null ? {
    for neighbor in lookup(local.adjacency, local.random_node, []) :
    "${local.random_node}_explores_${neighbor}_iter${var.iteration}_pass4" => {
      subject    = local.random_node
      predicate  = "explores"
      object     = neighbor
      iteration  = var.iteration
      inferred   = true
      combinator = "random_walk(weight)"
      pass       = 4
      weight     = lookup(local.normalized_node_weights, neighbor, 0.001)
    }
  } : {}

  # Merge all inference passes
  all_inferred = merge(
    local.inferred_pass1_I,
    local.inferred_pass2_K,
    local.inferred_pass3_S,
    local.inferred_pass4_random
  )
}

# ============================================================================
# Depth-Limited Graph Walks: BFS up to depth 6
# ============================================================================

locals {
  # Depth-1 reachability
  reachable_depth_1 = local.adjacency

  # Depth-2 reachability
  reachable_depth_2 = {
    for node in keys(local.adjacency) :
    node => distinct(flatten([
      lookup(local.adjacency, node, []),
      flatten([
        for neighbor in lookup(local.adjacency, node, []) :
        lookup(local.adjacency, neighbor, [])
      ])
    ]))
  }

  # Depth-3 reachability
  reachable_depth_3 = {
    for node in keys(local.adjacency) :
    node => distinct(flatten([
      lookup(local.reachable_depth_2, node, []),
      flatten([
        for neighbor in lookup(local.reachable_depth_2, node, []) :
        lookup(local.adjacency, neighbor, [])
      ])
    ]))
  }

  # Influence scores: how many nodes reachable within depth 3
  influence_scores = {
    for node in keys(local.adjacency) :
    node => length(lookup(local.reachable_depth_3, node, []))
  }
}

# ============================================================================
# Multiset: Observation counting with attention decay
# ============================================================================

locals {
  # Convert triples to atomics
  new_atomics_from_triples = {
    for k, v in local.new_triples_from_input :
    "${v.subject} ${v.predicate} ${v.object}" => 1
  }

  # Merge with previous atomics (increment counts)
  multiset_raw = merge(
    {
      for k, v in local.prev_atomics : k => v.count
    },
    {
      for atomic in keys(local.new_atomics_from_triples) :
      atomic => lookup(local.prev_atomics, atomic, { count = 0 }).count + 1
    }
  )

  # Confidence from frequency + temporal decay
  max_count = length(local.multiset_raw) > 0 ? max(values(local.multiset_raw)...) : 1
  confidence_map = {
    for atomic, count in local.multiset_raw :
    atomic => min(
      (count / (local.max_count + 1.0)) *
      (1.0 - (var.iteration - lookup(local.prev_atomics, atomic, { iteration = var.iteration }).iteration) * 0.01),
      0.99
    )
  }
}

# ============================================================================
# Resources: Materialize state
# ============================================================================

resource "terraform_data" "atomic" {
  for_each = local.multiset_raw

  input = {
    atomic     = each.key
    count      = each.value
    confidence = local.confidence_map[each.key]
    iteration  = var.iteration
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "terraform_data" "triple" {
  for_each = local.all_triples

  input = each.value

  lifecycle {
    create_before_destroy = true
  }
}

# NOTE: Inferred facts are computed locally but NOT persisted as resources
# This prevents state bloat - inferences are recomputed each iteration
# Only atomics and triples are persisted

# ============================================================================
# Recurrent Computation: Null resources to break cycles
# ============================================================================

resource "null_resource" "recurrent_pass" {
  triggers = {
    iteration      = var.iteration
    triple_hash    = sha256(jsonencode(keys(local.all_triples)))
    inference_hash = sha256(jsonencode(keys(local.all_inferred)))
    random_seed    = var.iteration * 7 + 13
  }
}

locals {
  computation_phase = var.iteration % 4

  attention_mode = local.computation_phase == 0 ? "extraction" : (
    local.computation_phase == 1 ? "inference" : (
      local.computation_phase == 2 ? "exploration" : "consolidation"
    )
  )
}

# ============================================================================
# Bidirectional Computation: Forward (learn) + Backward (generate)
# ============================================================================

locals {
  # === FORWARD PASS: Ingestion (already done above) ===
  # Input → Tokens → N-grams → Transition matrices
  # This happens in earlier sections

  # === BACKWARD PASS: Generation via Markov chains ===

  # Seed selection (perturbation via weighted sampling)
  # Use graph centrality to pick high-degree words as seeds
  seed_candidates = length(local.degrees) > 0 ? [
    for node, degree in local.degrees : node
    if degree > 0
  ] : []

  # Pick seed based on iteration (deterministic but varies)
  seed_index = length(local.seed_candidates) > 0 ? (
    var.iteration % length(local.seed_candidates)
  ) : 0

  seed_token = length(local.seed_candidates) > 0 ? (
    element(local.seed_candidates, local.seed_index)
  ) : (local.token_count > 0 ? local.tokens[0] : "")

  # Generate sequence via Markov walk (backward generation)
  # Token 1: seed
  gen_token_1 = local.seed_token
  gen_candidates_1 = lookup(local.transition_lists, local.gen_token_1, [])
  gen_token_2 = length(local.gen_candidates_1) > 0 ? element(
    local.gen_candidates_1,
    (var.iteration * 7) % length(local.gen_candidates_1)
  ) : ""

  # Token 2: follow from token 1
  gen_candidates_2 = local.gen_token_2 != "" ? lookup(local.transition_lists, local.gen_token_2, []) : []
  gen_token_3 = length(local.gen_candidates_2) > 0 ? element(
    local.gen_candidates_2,
    (var.iteration * 11) % length(local.gen_candidates_2)
  ) : ""

  # Token 3: follow from token 2
  gen_candidates_3 = local.gen_token_3 != "" ? lookup(local.transition_lists, local.gen_token_3, []) : []
  gen_token_4 = length(local.gen_candidates_3) > 0 ? element(
    local.gen_candidates_3,
    (var.iteration * 13) % length(local.gen_candidates_3)
  ) : ""

  # Build generated sequence
  generated_sequence = compact([
    local.gen_token_1,
    local.gen_token_2,
    local.gen_token_3,
    local.gen_token_4
  ])

  generated_text = length(local.generated_sequence) > 0 ? (
    join(" ", local.generated_sequence)
  ) : ""

  # === RESPONSE: Show both forward (learned) and backward (generated) ===
  response = local.token_count > 0 ? join(" | ", compact([
    # Forward pass results
    "Learned: [${join(", ", local.tokens)}]",
    "Transitions: ${length(local.transition_lists)} words",
    # Backward pass results
    length(local.generated_text) > 0 ? "Generated: \"${local.generated_text}\"" : "",
    # Inference stats
    "Inferences: ${length(local.all_inferred)} (I:${length(local.inferred_pass1_I)} K:${length(local.inferred_pass2_K)} S:${length(local.inferred_pass3_S)} R:${length(local.inferred_pass4_random)})"
  ])) : (
    # If no input but have state, generate anyway
    length(local.generated_text) > 0 ?
      "Generated: \"${local.generated_text}\" | Transitions: ${length(local.transition_lists)} words" :
      "Waiting for input"
  )
}

# ============================================================================
# Outputs: Observable universe
# ============================================================================

output "response" {
  value = local.response
}

output "bidirectional" {
  value = {
    # Forward pass (ingestion)
    forward = {
      input_tokens = local.tokens
      token_count  = local.token_count
    }
    # Backward pass (generation)
    backward = {
      seed_token        = local.seed_token
      generated_tokens  = local.generated_sequence
      generated_text    = local.generated_text
      generation_path   = [
        local.gen_token_1,
        "→ [${join(", ", local.gen_candidates_1)}]",
        local.gen_token_2,
        "→ [${join(", ", local.gen_candidates_2)}]",
        local.gen_token_3,
        "→ [${join(", ", local.gen_candidates_3)}]",
        local.gen_token_4
      ]
    }
  }
}

output "transitions" {
  value = {
    total_words     = length(keys(local.transition_lists))
    total_edges     = length(local.follow_edges)
    sample_transitions = {
      for word, followers in local.transition_lists :
      word => followers
      if length(followers) > 1  # Show only words with multiple followers
    }
  }
}

output "atomics" {
  value = {
    for k, v in terraform_data.atomic : k => {
      count      = v.input.count
      confidence = v.input.confidence
    }
  }
}

output "graph" {
  value = {
    nodes           = length(local.adjacency)
    edges           = length(local.all_triples)
    avg_degree      = local.avg_degree
    high_degree_nodes = [
      for node, degree in local.degrees : node
      if degree > local.avg_degree
    ]
    phase           = local.attention_mode
  }
}

output "inference" {
  value = {
    total_inferred  = length(local.all_inferred)
    pass1_I         = length(local.inferred_pass1_I)
    pass2_K         = length(local.inferred_pass2_K)
    pass3_S         = length(local.inferred_pass3_S)
    pass4_random    = length(local.inferred_pass4_random)
    # Sample inferences (not persisted, computed fresh each iteration)
    samples = {
      for k, v in local.all_inferred : k => {
        subject = v.subject
        predicate = v.predicate
        combinator = v.combinator
      }
      if length(keys(local.all_inferred)) <= 10 ||
         contains([for i in range(min(10, length(keys(local.all_inferred)))) : element(keys(local.all_inferred), i)], k)
    }
  }
}

output "recurrence" {
  value = {
    iteration = var.iteration
    phase     = local.computation_phase
    attention = local.attention_mode
    triggered = null_resource.recurrent_pass.id
  }
}

output "spaghetti_metrics" {
  value = {
    total_locals       = 80  # Approximate
    nesting_depth      = 4
    hardcoded_patterns = 0   # ZERO hardcoded patterns!
    learned_patterns   = length(local.transition_lists)
    ski_passes         = 4
    max_depth          = 3   # Currently computing depth-3
    beauty_coefficient = "∞"
  }
}
