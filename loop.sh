#!/bin/bash

# Clause: Conversational reasoning loop
# Each iteration: User input → Terraform apply → Show output → Repeat

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
NC='\033[0m'

echo "════════════════════════════════════════════════════"
echo "    Clause: Iterative World Modeling"
echo "════════════════════════════════════════════════════"
echo ""

# Check setup
if [ ! -f "main.tf" ]; then
  echo "Error: main.tf not found"
  exit 1
fi

if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init -upgrade > /dev/null 2>&1
  echo ""
fi

while true; do
  # Get user input (THE CLAUSE)
  echo -ne "${BLUE}You: ${NC}"
  read -r USER_INPUT

  # Handle meta-commands
  case "$USER_INPUT" in
    exit|quit)
      echo ""
      echo "Goodbye! 👋"
      exit 0
      ;;
    show|state)
      echo ""
      echo "═══ Full State ═══"
      terraform show 2>/dev/null
      echo ""
      continue
      ;;
    facts)
      echo ""
      echo "═══ Known Facts ═══"
      terraform output -json 2>/dev/null | jq -r '.current_facts.value[]? // empty' 2>/dev/null || echo "  (no facts yet)"
      echo ""
      continue
      ;;
    stats)
      echo ""
      echo "═══ Statistics ═══"
      terraform output -json stats 2>/dev/null | jq '.'
      echo ""
      continue
      ;;
    "")
      continue
      ;;
  esac

  # Write input to Terraform variable file
  cat > "input.auto.tfvars" <<EOF
user_input = "$USER_INPUT"
EOF

  # Generate plan and save to file (for review) - strip ANSI codes
  echo -ne "${GRAY}[Planning...]${NC}\r"
  terraform plan -no-color -out=tfplan.binary > PLAN.txt 2>&1

  # Apply terraform (suppress noise)
  echo -ne "${GRAY}[Applying...]${NC}\r"
  (terraform apply -auto-approve tfplan.binary 2>&1 | \
    grep -v "Refreshing state" | \
    grep -v "Reading" | \
    grep -v "terraform_data" | \
    grep -v "local_file" | \
    grep -v "data.external" | \
    grep -v "Apply complete" | \
    grep -v "Resources:" | \
    grep -v "Outputs:" || true) > /dev/null

  # Clean up binary plan
  rm -f "tfplan.binary"

  # Show response immediately
  RESPONSE=$(terraform output -raw response 2>/dev/null || echo "")
  echo -e "${GREEN}Clause: ${NC}$RESPONSE"
  echo ""
done
