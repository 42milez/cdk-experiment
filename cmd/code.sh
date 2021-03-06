#!/bin/bash
# shellcheck disable=SC1090

set -eu

readonly PROJECT_ROOT=$(pwd)

. "${PROJECT_ROOT}/cmd/helper/read_yaml.sh"
. "${PROJECT_ROOT}/cmd/helper/validate_env.sh"
. "${PROJECT_ROOT}/cmd/helper/validate_option.sh"

# --------------------------------------------------
#  Parse Command-Line Options
# --------------------------------------------------

positional=("$1") && shift

while [ $# -gt 0 ]; do
{
  if [ "$1" = '--help' ]; then
    read_yaml "${PROJECT_ROOT}/cmd/option.yml" "code.${positional[0]}.--help.val"
    exit 0
  fi

  opt=$(read_yaml "${PROJECT_ROOT}/cmd/option.yml" "code.${positional[0]}.$1.val")

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

set -- "${positional[@]}"

# --------------------------------------------------
#  Setup
# --------------------------------------------------

if [ -z "${ENV+UNDEFINED}" ]; then
  readonly ENV=$(read_yaml "${PROJECT_ROOT}/cmd/config.yml" 'env.development')
fi

if [ -z "${ENV+UNDEFINED}" ]; then
  readonly ENV='development'
fi

validate_env "${ENV}"

# --------------------------------------------------
#  Command Definitions
# --------------------------------------------------

readonly DOCKER_WORK_DIR='/var/project'
readonly CMD=$1

if "${CI=false}"; then
  readonly BASH_CMD='bash -c'
  readonly NPX_CMD='npx'
else
  readonly BASH_CMD='docker-compose run --rm bash'
  readonly NPX_CMD='docker-compose run --rm npx'
fi

if [ "${CMD}" = 'lint' ]; then
{
  targets=()

  while read -r path; do
  {
    if "${CI=false}"; then
      targets+=("${path}")
    else
      targets+=("$(echo "${path}" | perl -pe "s|${PROJECT_ROOT}|${DOCKER_WORK_DIR}|g")")
    fi
  }
  done < <(find                              \
    "${PROJECT_ROOT}"                        \
    -type f                                  \
    -name '*.ts'                             \
    -not -path "${PROJECT_ROOT}/cdk.out/*"   \
    -not -path "${PROJECT_ROOT}/layer.out/*" \
    -not -path "${PROJECT_ROOT}/node_modules/*")

  # shellcheck disable=SC2086
  $NPX_CMD eslint --fix ${targets[*]}
}
elif [ "${CMD}" = 'build' ]; then
{
  validate_option 'code' 'build'

  : 'PREPARE LAMBDA LAYER' &&
  {
    readonly LAMBDA_LAYER_SRC_DIR="${PROJECT_ROOT}/src/function/layer"
    readonly LAMBDA_LAYER_DEST_DIR="layer.out/${ENV}"

    printf 'Lambda Layer Source: %s\n' "${LAMBDA_LAYER_SRC_DIR}"
    printf 'Lambda Layer Target: %s\n' "${LAMBDA_LAYER_DEST_DIR}"

    commands=()

    while read -r dir; do
    {
      install_dir="${LAMBDA_LAYER_DEST_DIR}/${dir}/nodejs"
      mkdir -p "${install_dir}"
      cp "${LAMBDA_LAYER_SRC_DIR}/${dir}/package.json" "${install_dir}"

      # add 'dependencies' member if not exists
      if [ "$(jq '.dependencies?' "${install_dir}/package.json")" = 'null' ]; then
      {
        cat < "${install_dir}/package.json"     \
          | jq ". |= .+ {\"dependencies\": {}}" \
          > "${install_dir}/package-tmp.json"   \
        && mv "${install_dir}/package-tmp.json" "${install_dir}/package.json"
      }
      fi

      layer_name=$(jq -r '.name' "${install_dir}/package.json")

      # add self as a dependency
      cat < "${install_dir}/package.json"                                                                \
        | jq ".dependencies |= .+ {\"${layer_name}-${ENV}\": \"../../../../src/function/layer/${dir}\"}" \
        > "${install_dir}/package-tmp.json"                                                              \
      && mv "${install_dir}/package-tmp.json" "${install_dir}/package.json"

      printf '%s\n' "$(cat "${install_dir}/package.json")"

      # install 'dependencies' without 'devDependencies'
      commands+=("npm --prefix ${install_dir} install --production")
    }
    done < <(find "${LAMBDA_LAYER_SRC_DIR}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

    cmd=$(IFS=',' tmp="${commands[*]}" ; echo "${tmp//,/ && }")

    printf 'Commands To Be Executed: %s\n' "${cmd}"

    $BASH_CMD "${cmd}"

    printf '%s\n' "$(find ${LAMBDA_LAYER_DEST_DIR} -maxdepth 3)"
  }

  : 'TRANSPILE ALL .ts FILES' &&
  {
    $NPX_CMD tsc
  }
}
elif [ "${CMD}" = 'test' ]; then
{
  validate_option 'code' 'test'

  $NPX_CMD jest
}
elif [ "${CMD}" = 'snapshot' ]; then
{
  validate_option 'code' 'snapshot'

  $NPX_CMD jest --updateSnapshot
}
else
  echo "invalid command: ${CMD} is not defined"
fi
