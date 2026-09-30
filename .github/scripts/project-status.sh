#!/usr/bin/env bash
# Move issues on the "Dictus 2.0.0" project board (getdictus/projects/2).
#
#   project-status.sh <in-progress|in-review> <issue-number>...
#
# Forward-only: a card never moves back. `in-progress` moves a card only out of
# Todo (or no status); `in-review` moves it out of anything but Done. Moving to
# Done is GitHub's own built-in workflow (issue closed, PR merged).
#
# Only cards already on the board move. The board is the 2.0.0 lane; an issue
# outside it is logged and left alone rather than added.
#
# Needs GH_TOKEN with the `project` scope. DRY_RUN=1 prints without writing.
set -euo pipefail

PROJECT_ID="PVT_kwDOEB1jvM4BlQM5"
STATUS_FIELD_ID="PVTSSF_lADOEB1jvM4BlQM5zhj9xOk"
OPT_TODO="f75ad846"
OPT_IN_PROGRESS="47fc9ee4"
OPT_IN_REVIEW="b4af331b"
OPT_DONE="98236657"

REPO_OWNER="${REPO_OWNER:-getdictus}"
REPO_NAME="${REPO_NAME:-dictus-ios}"

target="${1:?usage: project-status.sh <in-progress|in-review> <issue>...}"
shift

case "$target" in
  in-progress) target_opt="$OPT_IN_PROGRESS"; allowed_from=("" "$OPT_TODO") ;;
  in-review)   target_opt="$OPT_IN_REVIEW";   allowed_from=("" "$OPT_TODO" "$OPT_IN_PROGRESS") ;;
  *) echo "unknown target: $target" >&2; exit 2 ;;
esac

for issue in "$@"; do
  # The board item for this issue, if any, and its current Status option.
  # On a GraphQL error gh prints the raw response instead of the jq result, so
  # a failed lookup (a PR number, a typo) must be discarded, not parsed.
  if ! item=$(gh api graphql \
    -f owner="$REPO_OWNER" -f name="$REPO_NAME" -F number="$issue" \
    -f query='query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        issue(number: $number) {
          projectItems(first: 20) {
            nodes {
              id
              project { id }
              fieldValueByName(name: "Status") {
                ... on ProjectV2ItemFieldSingleSelectValue { optionId }
              }
            }
          }
        }
      }
    }' \
    --jq ".data.repository.issue.projectItems.nodes[]
          | select(.project.id == \"$PROJECT_ID\")
          | \"\(.id) \(.fieldValueByName.optionId // \"\")\"" 2>/dev/null); then
    item=""
  fi

  if [[ -z "$item" ]]; then
    echo "#$issue: not on the board (or not an issue), left alone"
    continue
  fi

  item_id="${item%% *}"
  current="${item#* }"

  movable=false
  for from in "${allowed_from[@]}"; do
    [[ "$current" == "$from" ]] && movable=true
  done
  if [[ "$movable" != true ]]; then
    echo "#$issue: already past $target, left alone"
    continue
  fi

  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    echo "#$issue: would move to $target (dry run)"
    continue
  fi

  # Raw GraphQL, not `gh project item-edit`: that command checks for classic
  # token scopes and refuses the fine-grained PROJECT_TOKEN outright.
  gh api graphql \
    -f project="$PROJECT_ID" -f item="$item_id" -f field="$STATUS_FIELD_ID" -f option="$target_opt" \
    -f query='mutation($project: ID!, $item: ID!, $field: ID!, $option: String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $project, itemId: $item, fieldId: $field,
        value: { singleSelectOptionId: $option }
      }) { projectV2Item { id } }
    }' >/dev/null
  echo "#$issue: moved to $target"
done
