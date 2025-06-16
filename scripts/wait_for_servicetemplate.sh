#!/bin/bash
set -euo pipefail

# Timeout after 10 minutes (600 seconds)
TIMEOUT=$((10 * 60))
SECONDS=0

while (( SECONDS < TIMEOUT )); do
    invalid_count=$(KUBECONFIG="kcfg_k0rdent" kubectl get servicetemplate -A -o jsonpath='{range .items[*]}{.status.valid}{"\n"}{end}' | grep -c "false" || true)

    if [ "$invalid_count" -eq 0 ]; then
        echo "✅ All servicetemplates OK"
        break
    fi

    echo "⏳ Found $invalid_count invalid service templates (${SECONDS}s elapsed)"

    KUBECONFIG="kcfg_k0rdent" kubectl get servicetemplate -A -o jsonpath='{range .items[?(@.status.valid==false)]}{.metadata.namespace}{"/"}{.metadata.name}{": "}{.status.validationError}{"\n"}{end}'

    sleep 5
done

if (( SECONDS >= TIMEOUT )); then
    echo "❌ Timeout reached after ${TIMEOUT}s: Some service templates are still not validated"
    echo "🔍 Final service template status:"
    KUBECONFIG="kcfg_k0rdent" kubectl get servicetemplate -A -o wide
    exit 1
fi
