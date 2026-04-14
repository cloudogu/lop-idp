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
    "$(.bin/yq -r '.ldap.image.tag' < "${valuesFile}")"

  setImageTagInComponentPatchTemplate ".values.images.kubectl" \
    "$(.bin/yq -r '.ldap.persistence.resize.hook.image.tag' < "${valuesFile}")"

  setImageTagInComponentPatchTemplate ".values.images.cas" \
    "$(.bin/yq -r '.cas.containers.cas.image.tag' < "${valuesFile}")"

  setImageTagInComponentPatchTemplate ".values.images.chownInit" \
    "$(.bin/yq -r '.cas.initContainers.volumeChown.image.tag' < "${valuesFile}")"

  setImageTagInComponentPatchTemplate ".values.images.additionalMountsInit" \
    "$(.bin/yq -r '.cas.initContainers.additionalMounts.image.tag' < "${valuesFile}")"

  setImageTagInComponentPatchTemplate ".values.images.usermgt" \
    "$(.bin/yq -r '.usermgt.image.tag' < "${valuesFile}")"

  setImageTagInComponentPatchTemplate ".values.images.ldapMapper" \
    "$(.bin/yq -r '.\"ldap-mapper\".image.tag' < "${valuesFile}")"

  setImageTagInComponentPatchTemplate ".values.images.authRegistrationOperator" \
    "$(.bin/yq -r '.\"k8s-auth-registration-operator\".manager.image.tag' < "${valuesFile}")"
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
