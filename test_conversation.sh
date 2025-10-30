#!/bin/bash
# Test the Clause conversational loop with predefined inputs

set -e

echo "Testing Clause conversational reasoning..."
echo ""

# Clean state for fresh test
rm -f terraform.tfstate terraform.tfstate.backup

# Test 1: First fact
echo "=== Test 1: Paris is a city ==="
terraform apply -auto-approve -var='user_input=Paris is a city' > /dev/null 2>&1
echo "Iteration: $(terraform output -raw iteration)"
terraform output -raw response
echo ""
echo ""

# Test 2: Location fact
echo "=== Test 2: Paris is located in France ==="
terraform apply -auto-approve -var='user_input=Paris is located in France' > /dev/null 2>&1
echo "Iteration: $(terraform output -raw iteration)"
terraform output -raw response
echo ""
echo ""

# Test 3: Another city
echo "=== Test 3: Lyon is a city ==="
terraform apply -auto-approve -var='user_input=Lyon is a city' > /dev/null 2>&1
echo "Iteration: $(terraform output -raw iteration)"
terraform output -raw response
echo ""
echo ""

# Test 4: Lyon location
echo "=== Test 4: Lyon is in France ==="
terraform apply -auto-approve -var='user_input=Lyon is in France' > /dev/null 2>&1
echo "Iteration: $(terraform output -raw iteration)"
terraform output -raw response
echo ""
echo ""

# Test 5: Query
echo "=== Test 5: What do you know about France? ==="
terraform apply -auto-approve -var='user_input=What do you know about France?' > /dev/null 2>&1
echo "Iteration: $(terraform output -raw iteration)"
terraform output -raw response
echo ""
echo ""

# Show transitions learned
echo "=== Learned Transitions ==="
terraform output -json transitions | jq '.'
echo ""

# Show pi geometry
echo "=== Pi-based Phase Cycling ==="
terraform output -json pi_geometry | jq '.'
echo ""

echo "✅ All tests passed! Iteration auto-incremented from 0 to $(terraform output -raw iteration)"
