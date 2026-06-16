#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# Local-development helper for the LOP-IdP umbrella chart.
#
# Usage:
#   dev-components.sh build   # build dev image + dev chart for each selected component
#   dev-components.sh swap    # re-point umbrella deps at the local dev charts, then resolve
#
# Component resolution happens here: for every name in DEV_COMPONENT_NAMES the script
# looks up DEV_DIR_<name> (dashes mapped to underscores, e.g. ldap-mapper -> DEV_DIR_ldap_mapper).
# A component is "selected" for local development when its DEV_DIR_<name> is set.
#
# Environment (set by the Makefile):
#   always: DEV_DIR_<name> overrides
#   build : RUNTIME_ENV, NAMESPACE
#   swap  : BINARY_YQ, BINARY_HELM, HELM_TARGET_DIR

# The sub-components of the LOP-IdP umbrella chart.
DEV_COMPONENT_NAMES="ldap cas usermgt ldap-mapper k8s-auth-registration-operator"

# Resolve the source-dir ENV variable for a component, e.g. "ldap" -> $DEV_DIR_ldap.
# Prints the ENV variable's value, or "" if it is not set.
component_dir() {
  local name="$1"

  # The DEV_DIR_<name> variables use underscores, so map dashes in the component name to underscores
  # (${name//-/_} replaces every "-" with "_"):  ldap-mapper -> DEV_DIR_ldap_mapper
  local var="DEV_DIR_${name//-/_}"

  # ${!var} is an indirect reference: it expands to the value of the variable whose *name* is held in $var.
  # The ":-" yields "" when that variable is unset.
  printf '%s' "${!var:-}"
}

# Print the names of all components that have a DEV_DIR_<name> set, one per line.
selected_components() {
  local name
  for name in ${DEV_COMPONENT_NAMES:-}; do
    if [ -n "$(component_dir "$name")" ]; then
      echo "$name"
    fi
  done
}

# Build the dev image + dev chart for one sub-component.
build_component() {
  local name="$1" dir
  dir="$(component_dir "$name")"
  if [ ! -d "$dir" ]; then
    echo "ERROR: source dir for '$name' not found: '$dir'" >&2
    exit 1
  fi
  echo ">> [$name] building dev image and chart in $dir (RUNTIME_ENV=${RUNTIME_ENV})"
  make -C "$dir" helm-package image-import \
    STAGE=development RUNTIME_ENV="${RUNTIME_ENV}" NAMESPACE="${NAMESPACE}"
}

# Returns the dot-path of the image block within a sub-chart's values.yaml.
# Components that nest the image differently need an explicit entry.
image_key_path() {
  local name="$1"
  case "$name" in
    cas)                            echo "containers.cas.image" ;;
    k8s-auth-registration-operator) echo "manager.image" ;;
    *)                              echo "image" ;;
  esac
}

# Remove the image override for one sub-component from the umbrella chart's generated values.yaml.
# Without the override the sub-chart's own default values take effect.
strip_umbrella_image_override() {
  local name="$1"
  local key_path
  key_path="$(image_key_path "$name")"
  echo ">> [$name] removing image override from umbrella values.yaml (sub-chart default will be used)"
  "${BINARY_YQ}" -i "del(.\"${name}\".${key_path})" "${HELM_TARGET_DIR}/values.yaml"
}

# Re-point one generated chart dependency at its local dev chart.
# The dev version is derived from the built .tgz filename (e.g. ldap-2.6.10-7-dev.1).
swap_component() {
  local name="$1" dir
  dir="$(component_dir "$name")"
  if [ ! -d "$dir" ]; then
    echo "ERROR: source dir for '$name' not found: '$dir'" >&2
    exit 1
  fi

  local abs tgz ver
  abs="$(cd "$dir/target/k8s/helm" && pwd)"
  # ls -t picks the newest packaged chart
  tgz="$(ls -t "$abs/$name"-*.tgz 2>/dev/null | head -1 || true)"
  if [ -z "$tgz" ]; then
    echo "ERROR: no packaged chart for '$name' in $abs - run the build first" >&2
    exit 1
  fi
  # get the version by removing ".tgz" and the component-name from the filename
  ver="$(basename "$tgz" .tgz | sed "s/^$name-//")"

  echo ">> [$name] pointing chart dependency to file://$abs ($ver)"
  "${BINARY_YQ}" -i "(.dependencies[] | select(.name == \"$name\")).repository = \"file://$abs\"" "${HELM_TARGET_DIR}/Chart.yaml"
  "${BINARY_YQ}" -i "(.dependencies[] | select(.name == \"$name\")).version = \"$ver\"" "${HELM_TARGET_DIR}/Chart.yaml"
}

main() {
  local command="${1:-}"
  local components name
  components="$(selected_components)"

  case "$command" in
    build)
      if [ -z "$components" ]; then
        echo "No sub-component selected. Set a DEV_DIR_<name>, e.g. 'make dev-component-apply DEV_DIR_ldap=../ecosystem/containers/ldap'" >&2
        exit 1
      fi
      for name in $components; do
        build_component "$name"
      done
      ;;
    swap)
      # HELM_POST_GENERATE hook: a no-op unless a component is selected.
      if [ -z "$components" ]; then
        exit 0
      fi
      for name in $components; do
        swap_component "$name"
        strip_umbrella_image_override "$name"
      done
      echo "running 'helm dependency update' in ${HELM_TARGET_DIR}"
      "${BINARY_HELM}" dependency update "${HELM_TARGET_DIR}"
      ;;
    *)
      echo "usage: $0 {build|swap}" >&2
      exit 1
      ;;
  esac
}

main "$@"
