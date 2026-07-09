ARTIFACT_ID=lop-idp
MAKEFILES_VERSION=10.10.0
VERSION=1.3.0

.DEFAULT_GOAL:=help
ADDITIONAL_CLEAN=clean_charts
K8S_HELM_RESSOURCES=k8s/helm

# Wire the sub-component dev swap into the generated (target) umbrella chart.
# Must be set before including k8s-component.mk, because the helm-generate rules
# expand their prerequisites at parse time. The hook is a no-op unless a
# DEV_DIR_<name> is set, so normal builds are unaffected.
HELM_POST_GENERATE_TARGETS = dev-swap-dependencies

include build/make/variables.mk
include build/make/clean.mk
include build/make/release.mk
include build/make/k8s-component.mk
include build/make/self-update.mk

# Export DEV_DIR_* variables which are used in build/dev-components.sh
export $(filter DEV_DIR_%,$(.VARIABLES))

clean_charts:
	rm -rf ${K8S_HELM_RESSOURCES}/charts

##@ Release

.PHONY: lop-idp-release
lop-idp-release: ## Interactively starts the release workflow for lop-idp
	@echo "Starting git flow release..."
	@build/make/release.sh lop-idp

# Build the dev image + dev chart for each selected sub-component.
.PHONY: dev-build-components
dev-build-components: ${BINARY_YQ} ${BINARY_HELM}
	@RUNTIME_ENV="$(RUNTIME_ENV)" NAMESPACE="$(NAMESPACE)" \
		build/dev-components.sh build

# HELM_POST_GENERATE hook: re-point the generated chart dependencies (in target/) at the local
# dev charts and re-resolve them. Only components with a DEV_DIR_<name> set are swapped.
.PHONY: dev-swap-dependencies
dev-swap-dependencies:
	@BINARY_YQ="$(BINARY_YQ)" BINARY_HELM="$(BINARY_HELM)" HELM_TARGET_DIR="$(HELM_TARGET_DIR)" \
		build/dev-components.sh swap

## Build sub-components with a set DEV_DIR_<name> and deploy lop-idp via the component-operator. Usage: make dev-component-apply DEV_DIR_ldap=../ecosystem/containers/ldap
.PHONY: dev-component-apply
dev-component-apply: dev-build-components component-apply

## Build sub-components with a set DEV_DIR_<name> and deploy lop-idp directly via Helm (faster inner loop). Usage: make dev-component-helm-apply DEV_DIR_ldap=../ecosystem/containers/ldap
.PHONY: dev-component-helm-apply
dev-component-helm-apply: dev-build-components helm-apply
