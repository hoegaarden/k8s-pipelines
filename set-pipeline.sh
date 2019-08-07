#!/usr/bin/env bash

set -euo pipefail

readonly LPASS_PATH="${LPASS_PATH:-Shared-CF K8s C10s/hhorl-test-pipes}"
readonly CI_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"
readonly TMP_DIR="$( mktemp -d )"
trap 'rm -rf -- "$TMP_DIR"' EXIT

setPipe() {
  local pipeline="$1"
  shift

  local flyArgs=()
  local varsFiles=()
  local pipeDir="${CI_DIR}/${pipeline}"
  local lpassSecrets="${LPASS_PATH}/${pipeline}-creds.yaml"
  local credsFile="${TMP_DIR}/${pipeline}-creds.yaml"

  [ -d "$pipeDir" ] || {
    echo >&2 "ERR: Could not find the pipeline dir '$pipeDir'"
    return 1
  }

  mapfile -d '' -t varsFiles < <( find "$pipeDir" -name '*-vars.yaml' -print0 )
  flyArgs=( "${varsFiles[@]/#/--load-vars-from=}" )

  if lpass show --notes "$lpassSecrets" > "$credsFile" 2>/dev/null
  then
    flyArgs+=( "--load-vars-from=${credsFile}" )
  else
    echo >&2 "WARN: Cannot read '$lpassSecrets', not loading vars/creds from lpass"
  fi

  fly set-pipeline \
    --config="${pipeDir}/pipeline.yaml" \
    "${flyArgs[@]}" \
    --pipeline="${pipeline}" \
    "$@"
}

usage() {
  [ $# -lt 1 ] || {
    echo >&2 "$@"
    echo >&2
  }

  cat >&2 <<EOF
`basename $0` <pipeline> [fly args ...]

  Set a pipeline named <pipeline>.

  The <base directory> for all the pipeline configs is "${CI_DIR}/<pipeline>/".
  The pipeline file is expected to be found at "<base directory>/pipeline.yaml".
  If files matching the glob "<base directory>/*-vars.yaml" are found, they will be used as vars files and passed to fly.
  Any secrets are expected to be found in "${LPASS_PATH}/<pipeline>-vars.yaml", they will also be passed on to fly as vars files.

  Any additional [fly args] will be directly passed on to fly.
  This can be used to specify the target (-t <target name>) or any other option that the set-pipeline command can take.
EOF

  return 1
}

validateArgs() {
  [ $# -ge 1 ] || {
    usage 'No pipeline name provided'
    return 1
  }
}

main() {
  validateArgs "$@"
  setPipe "$@"
}

main "$@"

