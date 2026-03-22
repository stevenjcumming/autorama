#!/bin/bash

set -e

STATE_FILE=".claude/oneshot-state.json"
ACTION="$1"
shift || true

case "$ACTION" in
  init)
    # Initialize state with spec list
    # Usage: oneshot-state.sh init '<json_array>'
    SPECS_JSON="$1"
    if [ -z "$SPECS_JSON" ]; then
      echo "ERROR: No specs JSON provided"
      exit 1
    fi

    mkdir -p "$(dirname "$STATE_FILE")"

    if command -v jq &> /dev/null; then
      echo "$SPECS_JSON" | jq '{
        started_at: (now | todate),
        updated_at: (now | todate),
        specs: [.[] | . + {status: "pending", started_at: null, completed_at: null}]
      }' > "$STATE_FILE"
    elif command -v python3 &> /dev/null; then
      python3 -c "
import json, sys
from datetime import datetime, timezone
specs = json.loads(sys.argv[1])
now = datetime.now(timezone.utc).isoformat()
state = {
    'started_at': now,
    'updated_at': now,
    'specs': [{**s, 'status': 'pending', 'started_at': None, 'completed_at': None} for s in specs]
}
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
" "$SPECS_JSON"
    else
      echo "ERROR: Neither jq nor python3 found"
      exit 1
    fi

    echo "STATE_INITIALIZED:$(echo "$SPECS_JSON" | python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))" 2>/dev/null || echo "?")"
    ;;

  load)
    # Load current state
    if [ ! -f "$STATE_FILE" ]; then
      echo "NO_STATE"
      exit 0
    fi
    cat "$STATE_FILE"
    ;;

  update)
    # Update a spec's status
    # Usage: oneshot-state.sh update <spec_id> <status>
    SPEC_ID="$1"
    STATUS="$2"

    if [ -z "$SPEC_ID" ] || [ -z "$STATUS" ]; then
      echo "ERROR: Usage: oneshot-state.sh update <spec_id> <status>"
      exit 1
    fi

    if [ ! -f "$STATE_FILE" ]; then
      echo "ERROR: No state file found"
      exit 1
    fi

    if command -v jq &> /dev/null; then
      TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      tmp=$(jq --arg id "$SPEC_ID" --arg status "$STATUS" --arg ts "$TIMESTAMP" '
        .updated_at = $ts |
        .specs = [.specs[] |
          if .id == $id then
            .status = $status |
            if $status == "in_progress" then .started_at = $ts
            elif $status == "completed" or $status == "failed" then .completed_at = $ts
            else . end
          else . end
        ]
      ' "$STATE_FILE")
      echo "$tmp" > "$STATE_FILE"
    elif command -v python3 &> /dev/null; then
      python3 -c "
import json, sys
from datetime import datetime, timezone
spec_id = sys.argv[1]
status = sys.argv[2]
now = datetime.now(timezone.utc).isoformat()
with open('$STATE_FILE') as f:
    state = json.load(f)
state['updated_at'] = now
for s in state['specs']:
    if s['id'] == spec_id:
        s['status'] = status
        if status == 'in_progress':
            s['started_at'] = now
        elif status in ('completed', 'failed'):
            s['completed_at'] = now
        break
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
" "$SPEC_ID" "$STATUS"
    else
      echo "ERROR: Neither jq nor python3 found"
      exit 1
    fi

    echo "UPDATED:$SPEC_ID:$STATUS"
    ;;

  check-deps)
    # Check if all dependencies for a spec are completed
    # Usage: oneshot-state.sh check-deps <spec_id>
    SPEC_ID="$1"

    if [ ! -f "$STATE_FILE" ]; then
      echo "ERROR: No state file found"
      exit 1
    fi

    if command -v jq &> /dev/null; then
      RESULT=$(jq -r --arg id "$SPEC_ID" '
        (.specs[] | select(.id == $id) | .dependencies // []) as $deps |
        if ($deps | length) == 0 then "DEPS_MET"
        else
          [.specs[] | select(.id == ($deps[])) | select(.status != "completed") | .id] as $unmet |
          if ($unmet | length) == 0 then "DEPS_MET"
          else "DEPS_UNMET:" + ($unmet | join(","))
          end
        end
      ' "$STATE_FILE")
      echo "$RESULT"
    elif command -v python3 &> /dev/null; then
      python3 -c "
import json, sys
spec_id = sys.argv[1]
with open('$STATE_FILE') as f:
    state = json.load(f)
target = None
for s in state['specs']:
    if s['id'] == spec_id:
        target = s
        break
if not target:
    print(f'ERROR: Spec {spec_id} not found')
    sys.exit(1)
deps = target.get('dependencies', [])
if not deps:
    print('DEPS_MET')
    sys.exit(0)
status_map = {s['id']: s['status'] for s in state['specs']}
unmet = [d for d in deps if status_map.get(d) != 'completed']
if not unmet:
    print('DEPS_MET')
else:
    print('DEPS_UNMET:' + ','.join(unmet))
" "$SPEC_ID"
    else
      echo "ERROR: Neither jq nor python3 found"
      exit 1
    fi
    ;;

  status)
    # Print summary of current state
    if [ ! -f "$STATE_FILE" ]; then
      echo "NO_STATE"
      exit 0
    fi

    if command -v jq &> /dev/null; then
      jq -r '
        "TOTAL:" + (.specs | length | tostring),
        "COMPLETED:" + ([.specs[] | select(.status == "completed")] | length | tostring),
        "FAILED:" + ([.specs[] | select(.status == "failed")] | length | tostring),
        "PENDING:" + ([.specs[] | select(.status == "pending")] | length | tostring),
        "IN_PROGRESS:" + ([.specs[] | select(.status == "in_progress")] | length | tostring)
      ' "$STATE_FILE"
    elif command -v python3 &> /dev/null; then
      python3 -c "
import json
from collections import Counter
with open('$STATE_FILE') as f:
    state = json.load(f)
counts = Counter(s['status'] for s in state['specs'])
print(f'TOTAL:{len(state[\"specs\"])}')
print(f'COMPLETED:{counts.get(\"completed\", 0)}')
print(f'FAILED:{counts.get(\"failed\", 0)}')
print(f'PENDING:{counts.get(\"pending\", 0)}')
print(f'IN_PROGRESS:{counts.get(\"in_progress\", 0)}')
"
    else
      echo "ERROR: Neither jq nor python3 found"
      exit 1
    fi
    ;;

  *)
    echo "ERROR: Unknown action: $ACTION"
    echo "Usage: oneshot-state.sh <init|load|update|check-deps|status> [args...]"
    exit 1
    ;;
esac
