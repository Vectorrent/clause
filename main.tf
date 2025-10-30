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

  # Auto-increment iteration from previous state (truly self-contained!)
  prev_iteration = try(local.prev_state.outputs.iteration.value, 0)
  iteration = local.prev_iteration + 1

  # Extract ALL atomics from previous state (consolidated format)
  # Find the atomics resource
  prev_atomics_resources = try(local.prev_state.resources, [])
  prev_atomics_filtered = [
    for res in local.prev_atomics_resources :
    res if res.type == "terraform_data" && res.name == "atomics"
  ]

  # Extract atomics map (try/catch handles both missing resource and empty state)
  # Note: terraform_data stores in input.value, not just input
  prev_atomics = try(
    local.prev_atomics_filtered[0].instances[0].attributes.input.value,
    {}
  )

  # Extract ALL triples (consolidated format)
  prev_triples_filtered = [
    for res in local.prev_atomics_resources :
    res if res.type == "terraform_data" && res.name == "triples"
  ]

  prev_triples = try(
    local.prev_triples_filtered[0].instances[0].attributes.input.value,
    {}
  )
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
  # Include position index to handle duplicate pairs in same input
  bigrams = local.token_count >= 2 ? {
    for i in range(local.token_count - 1) :
    "${local.tokens[i]}_follows_${local.tokens[i+1]}_iter${local.iteration}_pos${i}" => {
      subject   = local.tokens[i]
      predicate = "follows"  # ONLY predicate - means "precedes in sequence"
      object    = local.tokens[i+1]
      iteration = local.iteration
    }
  } : {}

  # Extract trigrams for richer context
  trigrams = local.token_count >= 3 ? {
    for i in range(local.token_count - 2) :
    "${local.tokens[i]}_${local.tokens[i+1]}_leads_${local.tokens[i+2]}_iter${local.iteration}_pos${i}" => {
      subject   = "${local.tokens[i]}_${local.tokens[i+1]}"  # Compound subject
      predicate = "leads_to"
      object    = local.tokens[i+2]
      iteration = local.iteration
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
      max(1 - ((local.iteration - props.iteration) * local.decay_rate), 0.001)
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

  # ========================================================================
  # Sparse Connectivity: Golden-angle sampling for efficient wide updates
  # ========================================================================
  # Instead of full n×n connectivity, sample a sparse subset each iteration
  # Uses golden angle (137.5°) for optimal coverage (like sunflower seeds)

  all_atomic_keys = keys(local.prev_atomics)
  num_atomics = length(local.all_atomic_keys)

  # Sample size: sqrt(n) atomics per iteration (balance coverage vs cost)
  sparse_sample_size = max(floor(pow(local.num_atomics, 0.5)), 1)

  # Golden-angle-based sparse sampling (visits all atomics quasi-uniformly)
  sparse_sample_indices = local.num_atomics > 0 ? [
    for i in range(local.sparse_sample_size) :
    floor((local.iteration * local.sparse_sample_size + i) * local.golden_angle / (2 * local.pi) * local.num_atomics) % local.num_atomics
  ] : []

  sparse_sampled_atomics = {
    for idx in local.sparse_sample_indices :
    local.all_atomic_keys[idx] => local.prev_atomics[local.all_atomic_keys[idx]]
    if local.num_atomics > 0
  }

  # Pairwise distances in 6D space (only for sparse sample)
  # Distance = sqrt(Δconf² + Δcount² + Δiter² + ...) with normalization
  sparse_pairwise_distances = local.num_atomics > 1 ? {
    for key_a in keys(local.sparse_sampled_atomics) :
    key_a => {
      for key_b in local.all_atomic_keys :
      key_b => pow(
        pow(lookup(local.prev_atomics[key_a], "confidence", 0) - lookup(local.prev_atomics[key_b], "confidence", 0), 2) +
        pow(log(lookup(local.prev_atomics[key_a], "count", 1) + 1, 2) - log(lookup(local.prev_atomics[key_b], "count", 1) + 1, 2), 2) +
        pow((lookup(local.prev_atomics[key_a], "iteration", 0) - lookup(local.prev_atomics[key_b], "iteration", 0)) * 0.01, 2),
        0.5  # sqrt via pow(x, 0.5)
      ) if key_a != key_b
    }
  } : {}

  # ========================================================================
  # Bidirectional Weight Propagation (Lion-optimizer inspired)
  # ========================================================================
  # Forward pass: Normal weights (attraction)
  # Backward pass: Sign-flipped weights (repulsion/perturbation)
  # This explores both "what is" and "what is NOT" simultaneously

  # Determine which phase we're in (even/odd iterations alternate)
  weight_sign = local.iteration % 2 == 0 ? 1 : -1

  # Apply sign to sparse distances (bidirectional flow)
  signed_sparse_distances = {
    for key_a, distances in local.sparse_pairwise_distances :
    key_a => {
      for key_b, dist in distances :
      # Forward (even): positive influence (attraction)
      # Backward (odd): negative influence (repulsion/anti-pattern)
      key_b => dist * local.weight_sign
    }
  }

  # Weight adjustments from bidirectional flow
  # Accumulate influences across all sparse connections
  weight_adjustments = local.num_atomics > 0 ? {
    for atomic_key in local.all_atomic_keys :
    atomic_key => sum(flatten([
      for sampler_key, distances in local.signed_sparse_distances : [
        for target_key, signed_dist in distances :
        signed_dist if target_key == atomic_key
      ]
    ]))
  } : {}

  # Bidirectional phase name
  bidirectional_phase = local.weight_sign > 0 ? "forward_attract" : "backward_repel"
}

# ============================================================================
# Inference via SKI: Pure graph operations
# ============================================================================

locals {
  # Pass 1: I (Identity) - Attend to ALL nodes
  inferred_pass1_I = {
    for node in keys(local.adjacency) :
    "${node}_observed_iter${local.iteration}_pass1" => {
      subject    = node
      predicate  = "observed"
      object     = "pass1"
      iteration  = local.iteration
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
    "${node}_hub_iter${local.iteration}_pass2" => {
      subject    = node
      predicate  = "hub"
      object     = "high_degree"
      iteration  = local.iteration
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
      "${node}_connects_${neighbor}_iter${local.iteration}_pass3" => {
        subject    = node
        predicate  = "connects"
        object     = neighbor
        iteration  = local.iteration
        inferred   = true
        combinator = "S(neighbors)(weight)"  # Apply and combine
        pass       = 3
      }
      if length(neighbors) > 0
    }
  ]...) : {}

  # Pass 4: Weighted Random Walk
  random_node_idx = length(keys(local.adjacency)) > 0 ? (
    local.iteration % length(keys(local.adjacency))
  ) : 0
  random_node = length(keys(local.adjacency)) > 0 ? (
    element(keys(local.adjacency), local.random_node_idx)
  ) : null

  inferred_pass4_random = local.random_node != null ? {
    for neighbor in lookup(local.adjacency, local.random_node, []) :
    "${local.random_node}_explores_${neighbor}_iter${local.iteration}_pass4" => {
      subject    = local.random_node
      predicate  = "explores"
      object     = neighbor
      iteration  = local.iteration
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
  # Convert triples to atomics (allow duplicates via grouping with ...)
  # The ... operator groups duplicate keys into lists: [1, 1] for two occurrences
  new_atomics_from_triples_raw = {
    for k, v in local.new_triples_from_input :
    "${v.subject} ${v.predicate} ${v.object}" => 1...
  }

  # Sum the grouped values to get occurrence counts
  new_atomics_from_triples = {
    for atomic, counts in local.new_atomics_from_triples_raw :
    atomic => length(counts)  # counts is a list like [1, 1], length gives us 2
  }

  # Merge with previous atomics (increment counts by occurrence count)
  multiset_raw = merge(
    {
      for k, v in local.prev_atomics : k => v.count
    },
    {
      for atomic, count in local.new_atomics_from_triples :
      atomic => lookup(local.prev_atomics, atomic, { count = 0 }).count + count
    }
  )

  # Confidence from frequency + temporal decay
  max_count = length(local.multiset_raw) > 0 ? max(values(local.multiset_raw)...) : 1
  confidence_map = {
    for atomic, count in local.multiset_raw :
    atomic => min(
      (count / (local.max_count + 1.0)) *
      (1.0 - (local.iteration - lookup(local.prev_atomics, atomic, { iteration = local.iteration }).iteration) * 0.01),
      0.99
    )
  }
}

# ============================================================================
# Resources: Materialize state (consolidated)
# ============================================================================

# Store ALL atomics in a single resource (reduces terraform plan bloat)
resource "terraform_data" "atomics" {
  input = {
    for atomic_key, count_val in local.multiset_raw :
    atomic_key => {
      count      = count_val
      confidence = local.confidence_map[atomic_key]
      iteration  = local.iteration
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Store ALL triples in a single resource
resource "terraform_data" "triples" {
  input = local.all_triples

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
    iteration      = local.iteration
    triple_hash    = sha256(jsonencode(keys(local.all_triples)))
    inference_hash = sha256(jsonencode(keys(local.all_inferred)))
    random_seed    = local.iteration * 7 + 13
  }
}

locals {
  # Pi-based quasi-periodic phase cycling
  # Using π ensures phases never repeat exactly (irrational number)
  # This creates precessing orbits through state space
  pi = 3.14159265359
  golden_ratio = 1.61803398875

  # Continuous phase [0, 1) that cycles but never repeats
  phase_continuous = (local.iteration * local.pi) - floor(local.iteration * local.pi)

  # Discrete phase (0-3) but visits them in non-sequential order due to π
  computation_phase = floor(local.iteration * local.pi) % 4

  # Phase angle (radians) for geometric computations
  phase_angle = local.phase_continuous * 2 * local.pi  # [0, 2π)

  # Golden angle for sparse sampling (related to Fibonacci spirals)
  golden_angle = 2 * local.pi / (local.golden_ratio * local.golden_ratio)
  sampling_angle = (local.iteration * local.golden_angle) - floor(local.iteration * local.golden_angle / (2 * local.pi)) * 2 * local.pi

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
    local.iteration % length(local.seed_candidates)
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
    (local.iteration * 7) % length(local.gen_candidates_1)
  ) : ""

  # Token 2: follow from token 1
  gen_candidates_2 = local.gen_token_2 != "" ? lookup(local.transition_lists, local.gen_token_2, []) : []
  gen_token_3 = length(local.gen_candidates_2) > 0 ? element(
    local.gen_candidates_2,
    (local.iteration * 11) % length(local.gen_candidates_2)
  ) : ""

  # Token 3: follow from token 2
  gen_candidates_3 = local.gen_token_3 != "" ? lookup(local.transition_lists, local.gen_token_3, []) : []
  gen_token_4 = length(local.gen_candidates_3) > 0 ? element(
    local.gen_candidates_3,
    (local.iteration * 13) % length(local.gen_candidates_3)
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

output "iteration" {
  value = local.iteration
  description = "Auto-incremented iteration counter (self-tracked in state)"
}

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
  value = terraform_data.atomics.input
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
    iteration          = local.iteration
    phase_discrete     = local.computation_phase
    phase_continuous   = local.phase_continuous
    phase_angle_rad    = local.phase_angle
    attention          = local.attention_mode
    bidirectional      = local.bidirectional_phase
    weight_sign        = local.weight_sign
    triggered          = null_resource.recurrent_pass.id
  }
}

output "pi_geometry" {
  value = {
    pi                 = local.pi
    golden_ratio       = local.golden_ratio
    golden_angle       = local.golden_angle
    sampling_angle_rad = local.sampling_angle
    phase_continuous   = local.phase_continuous
    sparse_sample_size = local.sparse_sample_size
    sparse_coverage    = local.num_atomics > 0 ? "${floor(local.sparse_sample_size / max(local.num_atomics, 1) * 100)}%" : "0%"
  }
}

output "sparse_connectivity" {
  value = {
    total_atomics          = local.num_atomics
    sampled_this_iter      = length(local.sparse_sampled_atomics)
    sample_keys            = keys(local.sparse_sampled_atomics)
    sample_count           = length(local.sparse_pairwise_distances)
    bidirectional_phase    = local.bidirectional_phase
    weight_sign            = local.weight_sign
    showing_full_distances = local.num_atomics <= 20
    pairwise_distances     = local.num_atomics <= 20 ? local.sparse_pairwise_distances : {}
    weight_adjustments     = local.num_atomics <= 10 ? local.weight_adjustments : {
      note = "Too many atomics, showing summary only"
      total_adjustment = local.num_atomics > 0 ? sum(values(local.weight_adjustments)) : 0
    }
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
