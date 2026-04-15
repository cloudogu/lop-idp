#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

componentTemplateFile="k8s/helm/component-patch-tpl.yaml"
valuesFile="k8s/helm/values.yaml"

# this function will be sourced from release.sh and be called from release_functions.sh
update_versions_modify_files() {
  echo "Update image tags in component patch template"

  setImageTagInComponentPatchTemplate ".values.images.ldap" \
    "$(readRequiredValue '.ldap.image.tag')"

  setImageTagInComponentPatchTemplate ".values.images.kubectl" \
    "$(readRequiredValue '.ldap.persistence.resize.hook.image.tag')"

  setImageTagInComponentPatchTemplate ".values.images.cas" \
    "$(readRequiredValue '.cas.containers.cas.image.tag')"

  setImageTagInComponentPatchTemplate ".values.images.chownInit" \
    "$(readRequiredValue '.cas.initContainers.volumeChown.image.tag')"

  setImageTagInComponentPatchTemplate ".values.images.additionalMountsInit" \
    "$(readRequiredValue '.cas.initContainers.additionalMounts.image.tag')"

  setImageTagInComponentPatchTemplate ".values.images.usermgt" \
    "$(readRequiredValue '.usermgt.image.tag')"

  setImageTagInComponentPatchTemplate ".values.images.ldapMapper" \
    "$(readRequiredValue '.["ldap-mapper"].image.tag')"

  setImageTagInComponentPatchTemplate ".values.images.authRegistrationOperator" \
    "$(readRequiredValue '.["k8s-auth-registration-operator"].manager.image.tag')"
}

readRequiredValue() {
  local key="${1}"
  local value

  value=$(.bin/yq -r "${key}" < "${valuesFile}")
  if [[ -z "${value}" || "${value}" == "null" ]]; then
    echo "Could not read required value '${key}' from ${valuesFile}" >&2
    exit 1
  fi

  echo "${value}"
}

setAttributeInComponentPatchTemplate() {
  local key="${1}"
  local value="${2}"

  .bin/yq -i "${key} = \"${value}\"" "${componentTemplateFile}"
}

setImageTagInComponentPatchTemplate() {
  local key="${1}"
  local tag="${2}"
  local currentImage

  currentImage=$(.bin/yq -r "${key}" "${componentTemplateFile}")
  setAttributeInComponentPatchTemplate "${key}" "${currentImage%:*}:${tag}"
}

update_versions_stage_modified_files() {
  git add "${componentTemplateFile}"
}
