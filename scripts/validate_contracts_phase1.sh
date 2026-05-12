#!/bin/bash
# Atlantis Contract Validation - Phase 1 (Robust Version)

CHECKLIST="docs/contract-checklist.yaml"
REPORT_DIR="out/reports"
REPORT_FILE="$REPORT_DIR/phase1_validation.json"
TIMESTAMP=$(date -Iseconds)

# Always create report directory
mkdir -p "$REPORT_DIR"

# Function to write valid JSON (even on error)
write_json() {
    cat > "$REPORT_FILE" << 'JSONEOF'
[
JSONEOF
}

write_json

# Check if checklist exists
if [ ! -f "$CHECKLIST" ]; then
    cat >> "$REPORT_FILE" << EOF
  {
    "contract": "contract-checklist",
    "path": "$CHECKLIST",
    "status": "failed",
    "error_msg": "Contract checklist file not found",
    "timestamp": "$TIMESTAMP"
  }
]
EOF
    echo "ERROR: $CHECKLIST not found - created error report"
    exit 1
fi

# Check if python3 and yaml are available
if ! python3 -c "import yaml" 2>/dev/null; then
    cat >> "$REPORT_FILE" << EOF
  {
    "contract": "contract-checklist",
    "path": "$CHECKLIST",
    "status": "failed",
    "error_msg": "Python3 or PyYAML not installed",
    "timestamp": "$TIMESTAMP"
  }
]
EOF
    echo "ERROR: PyYAML not available - created error report"
    exit 1
fi

# Initialize counters
failed_count=0
total_count=0

# Extract and validate each contract using Python
python3 << 'PYEOF' > /tmp/contracts.txt
import yaml
import json

with open('docs/contract-checklist.yaml', 'r') as f:
    data = yaml.safe_load(f)

contracts = data.get('contracts', [])
for c in contracts:
    name = c.get('name', 'unknown')
    path = c.get('structure', {}).get('path', '')
    files = c.get('structure', {}).get('files', [])
    # Output as tab-separated
    print(f"{name}\t{path}\t{','.join(files)}")
PYEOF

# Process each contract
first_entry=true
while IFS=$'\t' read -r contract_name contract_path contract_files; do
    [ -z "$contract_name" ] && continue
    
    total_count=$((total_count + 1))
    status="passed"
    error_msg=""
    
    # Check directory
    if [ ! -d "$contract_path" ]; then
        status="failed"
        error_msg="Directory does not exist: $contract_path"
        failed_count=$((failed_count + 1))
    else
        # Check files
        IFS=',' read -ra files_array <<< "$contract_files"
        for file in "${files_array[@]}"; do
            [ -z "$file" ] && continue
            file_path="${contract_path}${file}"
            if [ ! -f "$file_path" ]; then
                status="failed"
                error_msg="Missing file: $file_path"
                failed_count=$((failed_count + 1))
                break
            elif [ ! -s "$file_path" ]; then
                status="failed"
                error_msg="File is empty: $file_path"
                failed_count=$((failed_count + 1))
                break
            fi
        done
    fi
    
    # Add comma separator
    if [ "$first_entry" = true ]; then
        first_entry=false
    else
        echo "," >> "$REPORT_FILE"
    fi
    
    # Write JSON entry
    cat >> "$REPORT_FILE" << EOF
  {
    "contract": "$contract_name",
    "path": "$contract_path",
    "status": "$status",
    "error_msg": "$error_msg",
    "timestamp": "$TIMESTAMP"
  }
EOF

done < /tmp/contracts.txt

# Close JSON array
echo "]" >> "$REPORT_FILE"

# Summary
echo "================================"
echo "Atlantis Contract Validation - Phase 1"
echo "================================"
echo "Total contracts checked: $total_count"
echo "Failed: $failed_count"
echo "Passed: $((total_count - failed_count))"
echo "Report: $REPORT_FILE"
echo "================================"

# Cleanup
rm -f /tmp/contracts.txt

if [ $failed_count -gt 0 ]; then
    echo "❌ Validation completed with $failed_count failures (expected in Dry-Run)"
    exit 1
else
    echo "✅ All contracts validated successfully"
    exit 0
fi
