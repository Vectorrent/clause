# Clause Quickstart

## Installation

```bash
# Clone the repo
git clone https://github.com/yourusername/clause
cd clause

# Initialize Terraform
cd terraform
terraform init
cd ..
```

## Usage

### Interactive Mode

Start a conversational session:

```bash
./loop.sh
```

Example conversation:
```
You: Paris is a city
Clause: I understood: Paris is_a city

You: Paris is located in France
Clause: I understood: Paris located_in France I can infer: France is_a country

You: What do you know about France?
Clause: I know: Paris located_in France, France is_a country

You: exit
```

### Commands

During a conversation:
- **Type normally**: Add facts or ask questions
- **`exit` or `quit`**: Stop the session
- **`show`**: Display full Terraform state
- **`facts`**: List all accumulated facts

### Automated Testing

Run the test suite:

```bash
./test_conversation.sh
```

This runs a predefined conversation and validates the reasoning.

## How It Works

1. **You provide input** → The "clause" (gate)
2. **Terraform applies** → Processes input via `process.py`
3. **State updates** → Facts accumulate in `state.json`
4. **Inference runs** → Reasoning rules derive new facts
5. **Loop repeats** → Next iteration sees accumulated knowledge

## Architecture

```
loop.sh (orchestrator)
    ↓
terraform/main.tf (state manager)
    ↓
terraform/process.py (reasoning engine)
    ↓
state.json (world model)
```

## What Can It Do?

### ✅ Fact Extraction
- "Paris is a city" → Extracts `Paris is_a city`
- "Paris is in France" → Extracts `Paris located_in France`

### ✅ Inference
- If "X is_a city" AND "X located_in Y"
  → Infers "Y is_a country"

### ✅ Queries
- "What do you know about X?" → Lists all facts about X
- "List all cities" → Lists entities of type "city"

## File Structure

```
clause/
├── loop.sh                    # Main interactive loop
├── test_conversation.sh       # Automated tests
├── terraform/
│   ├── main.tf               # Terraform configuration
│   ├── process.py            # Reasoning engine (SKI-based)
│   ├── state.json            # Accumulated facts (generated)
│   └── input.auto.tfvars     # Current input (generated)
├── POC_IMPLEMENTATION.md     # Detailed implementation guide
├── ANALYSIS.md               # Technical analysis
└── README.md                 # Full documentation
```

## Next Steps

- Read [README.md](./README.md) for full documentation
- Read [POC_IMPLEMENTATION.md](./POC_IMPLEMENTATION.md) for implementation details
- Read [ANALYSIS.md](./ANALYSIS.md) for technical analysis

## Troubleshooting

### "command not found: terraform"
Install Terraform: https://developer.hashicorp.com/terraform/install

### "command not found: python3"
Install Python 3: https://www.python.org/downloads/

### Terraform errors
```bash
cd terraform
rm -rf .terraform terraform.tfstate* state.json
terraform init
```

## Week 1 Status

✅ **COMPLETE!**

All Week 1 goals achieved:
- [x] Conversational loop works
- [x] Facts accumulate correctly
- [x] Inference rules work (SKI-based)
- [x] Queries work
- [x] All tests pass

Ready for Week 2: Multisets!
