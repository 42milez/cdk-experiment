#!/bin/bash
# shellcheck disable=SC1090

set -eu

readonly PROJECT_ROOT=$(pwd)

. "${PROJECT_ROOT}/cmd/helper/read_yaml.sh"
. "${PROJECT_ROOT}/cmd/helper/verify_env.sh"

#  Parse command-line options
# --------------------------------------------------
#  references:
#  - How do I parse command line arguments in Bash?
#    https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

positional=()

while [ $# -gt 0 ]; do
{
  opt=$(read_yaml "${PROJECT_ROOT}/cmd/option.yml" "cdk.$1")

  if [ -z "${opt}" ]; then
    positional+=("$1")
    shift
    continue
  fi

  eval "readonly ${opt}=$2"

  shift
  shift
}
done

set -- "${positional[@]}" # restore positional parameters

#  Set defaults
# --------------------------------------------------

readonly CONFIG_FILE="${PROJECT_ROOT}/cmd/config.yml"

if [ -z "${AWS_PROFILE+UNDEFINED}" ]; then
{
  readonly AWS_PROFILE=$(read_yaml "${CONFIG_FILE}" 'cli.profile')
  export AWS_PROFILE
}
fi

if [ -z "${AWS_DEFAULT_REGION+UNDEFINED}" ]; then
{
  readonly AWS_DEFAULT_REGION=$(read_yaml "${CONFIG_FILE}" 'cli.region')
  export AWS_DEFAULT_REGION
}
fi

export AWS_PROFILE
export AWS_DEFAULT_REGION

#  Command definitions
# --------------------------------------------------

readonly CDK_CMD="docker-compose run
  -e AWS_PROFILE=${AWS_PROFILE}
  -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
  --rm cdk"
readonly CMD=$1
readonly CDK_OUT_DIR='cdk.out'

# BOOTSTRAP

if [ "${CMD}" = 'bootstrap' ]; then
{
  $CDK_CMD bootstrap -o "${PROJECT_ROOT}/${CDK_OUT_DIR}/bootstrap"
  exit 0
}
fi

# LIST / DEPLOY / DESTROY / SYNTH

if [ -z "${ENV+UNDEFINED}" ]; then
{
  readonly ENV=$(read_yaml "${PROJECT_ROOT}/cmd/config.yml" 'env.development')
}
fi

verify_env "${ENV}"

if [ "${CMD}" = 'list' ]; then
{
  $CDK_CMD list -o "${PROJECT_ROOT}/${CDK_OUT_DIR}/${ENV}" -c "env=${ENV}"
  exit 0
}
fi

if [ -z "${STACK+UNDEFINED}" ]; then
{
  echo 'invalid argument: --stack is required.'
  exit 1
}
fi

if [ "${CMD}" = 'deploy' ]; then
{
  $CDK_CMD deploy                              \
    -o "${PROJECT_ROOT}/${CDK_OUT_DIR}/${ENV}" \
    -c "env=${ENV}"                            \
    "${STACK}-${ENV}"
}
elif [ "${CMD}" = 'destroy' ]; then
{
  $CDK_CMD destroy                             \
    -o "${PROJECT_ROOT}/${CDK_OUT_DIR}/${ENV}" \
    -c "env=${ENV}"                            \
    "${STACK}-${ENV}"
}
elif [ "${CMD}" = 'synth' ]; then
{
  $CDK_CMD cdk synth                           \
    -o "${PROJECT_ROOT}/${CDK_OUT_DIR}/${ENV}" \
    -c "env=${ENV}"                            \
    "${STACK}-${ENV}"
}
else
{
  echo "invalid command: ${CMD} is not defined"
}
fi
