#!/bin/bash
# Compare pinned engine versions against the latest upstream releases.
#
# Emits one JSON object per line: {"engine","current","latest","update"}.
# Pins are read from the same files the upgrade PRs edit, so a bump lands
# here automatically. TokenSpeed is a source build pinned to a commit, so
# its "versions" are SHAs and any divergence from upstream main counts as
# an update.
#
# Requires: curl, jq; GH_TOKEN for the TokenSpeed upstream lookup.

set -euo pipefail
cd "$(dirname "$0")/.."

emit() { # engine current latest
    local update=false
    if [ "$1" = "tokenspeed" ]; then
        [ "$2" != "$3" ] && update=true
    else
        [ "$(printf '%s\n%s\n' "$2" "$3" | sort -V | tail -1)" != "$2" ] && update=true
    fi
    jq -cn --arg e "$1" --arg c "$2" --arg l "$3" --argjson u "$update" \
        '{engine: $e, current: $c, latest: $l, update: $u}'
}

sglang_current=$(sed -n 's/.*"sglang\[all\]==\([^"]*\)".*/\1/p' scripts/ci_install_sglang.sh | head -1)
sglang_latest=$(curl -fsS https://pypi.org/pypi/sglang/json | jq -r .info.version)
emit sglang "$sglang_current" "$sglang_latest"

vllm_current=$(sed -n "s/.*default: 'vllm\/vllm-openai:v\([0-9.]*\)'.*/\1/p" .github/workflows/release-vllm-docker.yml | head -1)
vllm_latest=$(curl -fsS https://pypi.org/pypi/vllm/json | jq -r .info.version)
emit vllm "$vllm_current" "$vllm_latest"

trtllm_current=$(sed -n 's/^TRTLLM_VERSION="\(.*\)"$/\1/p' scripts/ci_install_trtllm.sh | head -1)
trtllm_latest=$(curl -fsS https://pypi.nvidia.com/tensorrt-llm/ \
    | grep -o 'tensorrt_llm-[0-9][^-]*' | sed 's/tensorrt_llm-//' | sort -uV | tail -1)
emit tensorrt-llm "$trtllm_current" "$trtllm_latest"

tokenspeed_current=$(sed -n 's/.*TOKENSPEED_REF:-\([0-9a-f]*\)}.*/\1/p' scripts/ci_install_tokenspeed.sh | head -1)
tokenspeed_latest=$(gh api repos/lightseekorg/tokenspeed/commits/main --jq .sha)
emit tokenspeed "$tokenspeed_current" "$tokenspeed_latest"
