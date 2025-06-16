#!/bin/bash
set -euo pipefail

while true; do
    invalid_count=$(KUBECONFIG="kcfg_k0rdent" kubectl get servicetemplate -A -o jsonpath='{range .items[*]}{.status.valid}{"\n"}{end}' | grep -c "false" || true)

    if [ "$invalid_count" -eq 0 ]; then
        echo "✅ All servicetemplates OK"
        break
    fi
    echo "⏳ Found $invalid_count invalid service templates"

    KUBECONFIG="kcfg_k0rdent" kubectl get servicetemplate -A -o jsonpath='{range .items[?(@.status.valid==false)]}{.metadata.namespace}{"/"}{.metadata.name}{": "}{.status.validationError}{"\n"}{end}'

    sleep 5
done
