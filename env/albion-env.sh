#!/usr/bin/env bash
#
# Configures Claude Code to use GLM-5.2 through Z.ai's Anthropic-compatible
# endpoint for Albion sessions. This file is sourced by bash or zsh, not
# executed, so it deliberately does not use `set -euo pipefail`; changing shell
# options here would leak into the caller despite the normal CONVENTIONS.md
# shell-script rule.
#
# Inputs:
#   ALBION_AUTH_LANE          Optional auth lane: `plan` (default) or `api`.
#   ALBION_ZAI_PLAN_TOKEN     Preferred token for the `plan` lane.
#   ALBION_ZAI_API_KEY        Preferred token for the `api` lane.
#   ALBION_ZAI_TOKEN          Fallback token when the lane-specific token is
#                             unset.
#   ALBION_ALLOW_OVERRIDES    When set to `1`, existing
#                             ANTHROPIC_DEFAULT_*_MODEL values are respected.
#   CLAUDE_CODE_EFFORT_LEVEL  Must be unset. Claude Code treats it as a global
#                             override, which disables Albion's per-task effort
#                             routing through skill and agent frontmatter.
#
# Failure modes:
#   - CLAUDE_CODE_EFFORT_LEVEL is set: unset it before sourcing this file.
#   - ALBION_AUTH_LANE is not `plan` or `api`: set it to one of those values.
#   - The selected lane has no resolvable token: set the lane-specific token or
#     ALBION_ZAI_TOKEN. Token values are never printed.

if [ -n "${CLAUDE_CODE_EFFORT_LEVEL+x}" ]; then
  printf '%s\n' \
    'CLAUDE_CODE_EFFORT_LEVEL is set; unset CLAUDE_CODE_EFFORT_LEVEL before sourcing env/albion-env.sh because it kills Albion per-task effort routing.' >&2
  return 1
fi

if [ -n "${ALBION_AUTH_LANE+x}" ]; then
  albion_auth_lane="${ALBION_AUTH_LANE}"
else
  albion_auth_lane="plan"
fi

case "${albion_auth_lane}" in
  plan)
    if [ -n "${ALBION_ZAI_PLAN_TOKEN+x}" ]; then
      albion_auth_token="${ALBION_ZAI_PLAN_TOKEN}"
    elif [ -n "${ALBION_ZAI_TOKEN+x}" ]; then
      albion_auth_token="${ALBION_ZAI_TOKEN}"
    else
      albion_auth_token=""
    fi
    if [ -z "${albion_auth_token}" ]; then
      printf '%s\n' \
        'ALBION_ZAI_PLAN_TOKEN is unset or empty for ALBION_AUTH_LANE=plan; set ALBION_ZAI_PLAN_TOKEN or fallback ALBION_ZAI_TOKEN before sourcing env/albion-env.sh.' >&2
      return 1
    fi
    ;;
  api)
    if [ -n "${ALBION_ZAI_API_KEY+x}" ]; then
      albion_auth_token="${ALBION_ZAI_API_KEY}"
    elif [ -n "${ALBION_ZAI_TOKEN+x}" ]; then
      albion_auth_token="${ALBION_ZAI_TOKEN}"
    else
      albion_auth_token=""
    fi
    if [ -z "${albion_auth_token}" ]; then
      printf '%s\n' \
        'ALBION_ZAI_API_KEY is unset or empty for ALBION_AUTH_LANE=api; set ALBION_ZAI_API_KEY or fallback ALBION_ZAI_TOKEN before sourcing env/albion-env.sh.' >&2
      return 1
    fi
    ;;
  *)
    printf '%s\n' \
      'ALBION_AUTH_LANE must be plan or api; set ALBION_AUTH_LANE=plan or ALBION_AUTH_LANE=api before sourcing env/albion-env.sh.' >&2
    return 1
    ;;
esac

export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
export ANTHROPIC_AUTH_TOKEN="${albion_auth_token}"

if [ "${ALBION_ALLOW_OVERRIDES:-}" = "1" ]; then
  export ANTHROPIC_DEFAULT_OPUS_MODEL="${ANTHROPIC_DEFAULT_OPUS_MODEL:-glm-5.2[1m]}"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="${ANTHROPIC_DEFAULT_SONNET_MODEL:-glm-5.2[1m]}"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-glm-5-turbo}"
else
  export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.2[1m]"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.2[1m]"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5-turbo"
fi

export API_TIMEOUT_MS=3000000
export CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=131072

export CLAUDE_CODE_ATTRIBUTION_HEADER=0
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1
export CLAUDE_CODE_STOP_HOOK_BLOCK_CAP=4

export ALBION_AUTH_LANE="${albion_auth_lane}"
export ALBION_ENV_LOADED=1

unset albion_auth_lane
unset albion_auth_token
