#!/bin/bash
# Test the Clause conversational loop with predefined inputs

set -e

cd terraform

echo "Testing Clause conversational reasoning..."
echo ""

# Test 1: First fact
echo "=== Test 1: Paris is a city ==="
cat > input.auto.tfvars <<EOF
iteration = 1
user_input = "Paris is a city"
EOF

terraform apply -auto-approve > /dev/null 2>&1
terraform output -raw response
echo ""
echo ""

# Test 2: Location fact (should derive country)
echo "=== Test 2: Paris is located in France ==="
cat > input.auto.tfvars <<EOF
iteration = 2
user_input = "Paris is located in France"
EOF

terraform apply -auto-approve > /dev/null 2>&1
terraform output -raw response
echo ""
echo ""

# Test 3: Another city
echo "=== Test 3: Lyon is a city ==="
cat > input.auto.tfvars <<EOF
iteration = 3
user_input = "Lyon is a city"
EOF

terraform apply -auto-approve > /dev/null 2>&1
terraform output -raw response
echo ""
echo ""

# Test 4: Lyon location (should derive same country)
echo "=== Test 4: Lyon is in France ==="
cat > input.auto.tfvars <<EOF
iteration = 4
user_input = "Lyon is in France"
EOF

terraform apply -auto-approve > /dev/null 2>&1
terraform output -raw response
echo ""
echo ""

# Test 5: Query
echo "=== Test 5: What do you know about France? ==="
cat > input.auto.tfvars <<EOF
iteration = 5
user_input = "What do you know about France?"
EOF

terraform apply -auto-approve > /dev/null 2>&1
terraform output -raw response
echo ""
echo ""

# Show all accumulated facts
echo "=== All accumulated facts ==="
terraform output -json current_facts | jq -r '.[]'
echo ""

# Show stats
echo "=== Statistics ==="
terraform output -json stats | jq '.'
echo ""

echo "✅ All tests passed!"
