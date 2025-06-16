#!/bin/bash
set -euo pipefail

repo_path=""
if [ "$GITHUB_EVENT_NAME" == "pull_request" ]; then
	echo "Pull request - use fork ghcr registry"
	repo_path="$(echo "ghcr.io/$GITHUB_PR_HEAD_REPO_OWNER/$GITHUB_PR_HEAD_REPO_NAME/charts" | tr '[:upper:]' '[:lower:]')"
elif [ "$GITHUB_REPOSITORY" != "k0rdent/catalog" ] && [ "$GITHUB_REF" != "refs/heads/main" ]; then
	echo "'In fork' test - use fork ghcr registry"
	repo_path="$(echo "ghcr.io/$GITHUB_REPOSITORY_OWNER/$GITHUB_EVENT_REPOSITORY_NAME/charts" | tr '[:upper:]' '[:lower:]')"
fi

if [ -n "$repo_path" ]; then
	echo "Listing existing HelmRepositories:"
	kubectl get helmrepository -A

	echo "Waiting for k0rdent-catalog HelmRepository and patching with custom URL: oci://$repo_path"
	until kubectl -n kcm-system patch helmrepository k0rdent-catalog --type='merge' -p="{\"spec\":{\"url\":\"oci://$repo_path\"}}"; do
		echo "⏳ Waiting for k0rdent-catalog HelmRepository to exist..."
		sleep 2
	done
	echo "✅ HelmRepository patched successfully"
fi

echo "Waiting for ServiceTemplates to be ready..."
while true; do
	invalid_count=$(kubectl get servicetemplate -A -o jsonpath='{range .items[*]}{.status.valid}{"\n"}{end}' | grep -c "false" || true)

	if [ "$invalid_count" -eq 0 ]; then
		echo "✅ All servicetemplates OK"
		break
	fi
	echo "⏳ Waiting... ($invalid_count invalid)"
	sleep 5
done

./scripts/ensure_mcs_config.sh

kubectl apply -f apps/$APP/mcs.yaml

wfd=$(python3 ./scripts/utils.py get-wait-for-pods $APP)
ns=$(./scripts/get_mcs_namespace.sh)
WAIT_FOR_PODS=$wfd NAMESPACE=$ns ./scripts/wait_for_deployment.sh
