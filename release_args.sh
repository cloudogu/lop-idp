#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

componentTemplateFile=k8s/helm/component-patch-tpl.yaml
k8sLopIdpTempChart="/tmp/k8s-lop-idp"
k8sLopIdpTempValues="${k8sLopIdpTempChart}/values.yaml"
k8sLopIdpTempChartYaml="${k8sLopIdpTempChart}/Chart.yaml"

k8sLopIdpValues="k8s/helm/values.yaml"

# this function will be sourced from release.sh and be called from release_functions.sh
update_versions_modify_files() {
  echo "Update helm dependencies"
  make helm-update-dependencies  > /dev/null

  # Extract k8s-lop-idp chart
  local k8sLopIdpVersion
  k8sLopIdpVersion=$(.bin/yq '.dependencies[] | select(.name=="k8s-lop-idp").version' < "k8s/helm/Chart.yaml")
  local k8sLopIdpPackage
  k8sLopIdpPackage="k8s/helm/charts/k8s-lop-idp-${k8sLopIdpVersion}.tgz"

  echo "Extract k8s-lop-idp helm chart"
  tar -zxvf "${k8sLopIdpPackage}" -C "/tmp" > /dev/null

  local k8sLopIdpAppVersion
  k8sLopIdpAppVersion=$(.bin/yq '.appVersion' < "${k8sLopIdpTempChartYaml}")

  echo "Set images in component patch template"

  local k8sLopIdpKubectlRegistry
  local k8sLopIdpKubectlRepo
  local k8sLopIdpKubectlTag
  k8sLopIdpKubectlRegistry=$(.bin/yq '.k8s-lop-idp.kubectlImage.registry' < "${k8sLopIdpValues}")
  k8sLopIdpKubectlRepo=$(.bin/yq '.k8s-lop-idp.kubectlImage.repository' < "${k8sLopIdpValues}")
  k8sLopIdpKubectlTag=$(.bin/yq '.k8s-lop-idp.kubectlImage.tag' < "${k8sLopIdpValues}")
  setAttributeInComponentPatchTemplate ".values.images.kubectl" "${k8sLopIdpKubectlRegistry}/${k8sLopIdpKubectlRepo}:${k8sLopIdpKubectlTag}"

  local k8sLopIdpImageRegistry
  local k8sLopIdpImageRepo
  k8sLopIdpImageRegistry=$(.bin/yq '.k8s-lop-idp.image.registry' < "${k8sLopIdpTempValues}")
  k8sLopIdpImageRepo=$(.bin/yq '.k8s-lop-idp.image.repository' < "${k8sLopIdpTempValues}")
  setAttributeInComponentPatchTemplate ".values.images.k8s-lop-idp" "${k8sLopIdpImageRegistry}/${k8sLopIdpImageRepo}:${k8sLopIdpAppVersion}"

  local k8sLopIdpCanaryRegistry
  local k8sLopIdpCanaryRepo
  k8sLopIdpCanaryRegistry=$(.bin/yq '.k8s-lop-idpCanary.image.registry' < "${k8sLopIdpTempValues}")
  k8sLopIdpCanaryRepo=$(.bin/yq '.k8s-lop-idpCanary.image.repository' < "${k8sLopIdpTempValues}")
  setAttributeInComponentPatchTemplate ".values.images.k8s-lop-idpCanary" "${k8sLopIdpCanaryRegistry}/${k8sLopIdpCanaryRepo}:${k8sLopIdpAppVersion}"

  local k8sLopIdpGatewayRegistry
  local k8sLopIdpGatewayRepo
  local k8sLopIdpGatewayTag
  k8sLopIdpGatewayRegistry=$(.bin/yq '.gateway.image.registry' < "${k8sLopIdpTempValues}")
  k8sLopIdpGatewayRepo=$(.bin/yq '.gateway.image.repository' < "${k8sLopIdpTempValues}")
  k8sLopIdpGatewayTag=$(.bin/yq '.gateway.image.tag' < "${k8sLopIdpTempValues}")
  setAttributeInComponentPatchTemplate ".values.images.gateway" "${k8sLopIdpGatewayRegistry}/${k8sLopIdpGatewayRepo}:${k8sLopIdpGatewayTag}"

  local k8sLopIdpSidecarRegistryRepo
  local k8sLopIdpSidecarTag
  k8sLopIdpSidecarRegistryRepo=$(.bin/yq '.sidecar.image.repository' < "${k8sLopIdpTempValues}")
  k8sLopIdpSidecarTag=$(.bin/yq '.sidecar.image.tag' < "${k8sLopIdpTempValues}")
  setAttributeInComponentPatchTemplate ".values.images.sidecar" "${k8sLopIdpSidecarRegistryRepo}:${k8sLopIdpSidecarTag}"

  rm -rf ${k8sLopIdpTempChart}
}

setAttributeInComponentPatchTemplate() {
  local key="${1}"
  local value="${2}"

  .bin/yq -i "${key} = \"${value}\"" "${componentTemplateFile}"
}

update_versions_stage_modified_files() {
  git add "${componentTemplateFile}"
}
