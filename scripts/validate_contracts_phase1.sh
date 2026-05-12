#!/bin/bash
# Atlantis Contract Validation - Phase 1
# Validates all guarded boundaries from contract-checklist.yaml

set -e

CHECKLIST="docs/contract-checklist.yaml"
REPORT_DIR="out/reports"
REPORT_FILE="$REPORT_DIR/phase1_validation.json"

# Create report directory
mkdir -p "$REPORT_DIR"

# Initialize JSON array
echo "[" > "$REPORT_FILE"

# Check if checklist exists
if [ ! -f "$CHECKLIST" ]; then
    echo "  {" >> "$REPORT_FILE"
    echo "    \"contract\": \"contract-checklist.yaml\"," >> "$REPORT_FILE"
    echo "    \"path\": \"$CHECKLIST\"," >> "$REPORT_FILE"
    echo "    \"status\": \"failed\"," >> "$REPORT_FILE"
    echo "    \"error_msg\": \"Contract checklist not found\"," >> "$REPORT_FILE"
    echo "    \"timestamp\": \"$(date -Iseconds)\"" >> "$REPORT_FILE"
    echo "  }" >> "$REPORT_FILE"
    echo "]" >> "$REPORT_FILE"
    echo "ERROR: $CHECKLIST not found"
    exit 1
fi

# Parse contracts from YAML and validate each
first_entry=true
failed_count=0

# Extract contract names and paths using python
contracts=$(python3 -c "
import yaml
with open('$CHECKLIST', 'r') as f:
    data = yaml.safe_load(f)
for c in data.get('contracts', []):
    name = c.get('name', 'unknown')
    path = c.get('structure', {}).get('path', '')
    files = c.get('structure', {}).get('files', [])
    print(f'{name}|{path}|{','.join(files)}')
")

while IFS='|' read -r contract_name contract_path contract_files; do
    [ -z "$contract_name" ] && continue
    
    status="passed"
    error_msg=""
    
    # Check if directory exists
    if [ ! -d "$contract_path" ]; then
        status="failed"
        error_msg="Directory does not exist: $contract_path"
        ((failed_count++))
    else
        # Check required files
        IFS=',' read -ra files_array <<< "$contract_files"
        for file in "${files_array[@]}"; do
            [ -z "$file" ] && continue
            file_path="$contract_path$file"
            if [ ! -f "$file_path" ]; then
                status="failed"
                error_msg="Missing file: $file_path"
                ((failed_count++))
                break
            elif [ ! -s "$file_path" ]; then
                status="failed"
                error_msg="File is empty: $file_path"
                ((failed_count++))
                break
            fi
        done
    fi
    
    # Add comma for previous entry
    if [ "$first_entry" = true ]; then
        first_entry=false
    else
        echo "," >> "$REPORT_FILE"
    fi
    
    # Write JSON entry
    echo "  {" >> "$REPORT_FILE"
    echo "    \"contract\": \"$contract_name\"," >> "$REPORT_FILE"
    echo "    \"path\": \"$contract_path\"," >> "$REPORT_FILE"
    echo "    \"status\": \"$status\"," >> "$REPORT_FILE"
    echo "    \"error_msg\": \"$error_msg\"," >> "$REPORT_FILE"
    echo "    \"timestamp\": \"$(date -Iseconds)\"" >> "$REPORT_FILE"
    echo "  }" >> "$REPORT_FILE"
    
done <<< "$contracts"

# Close JSON array
echo "]" >> "$REPORT_FILE"

# Summary
echo "================================"
echo "Validation Summary"
echo "================================"
echo "Total contracts: $(echo "$contracts" | grep -c .)"
echo "Failed: $failed_count"
echo "Report: $REPORT_FILE"
echo "================================"

# Exit with error if any failed
if [ $failed_count -gt 0 ]; then
    echo "❌ Validation failed with $failed_count errors"
    exit 1
else
    echo "✅ All contracts validated successfully"
    exit 0
fi
