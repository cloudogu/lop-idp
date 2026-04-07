ARTIFACT_ID=lop-idp
GOTAG=1.26.0
MAKEFILES_VERSION=10.7.3
VERSION=0.1.0

.DEFAULT_GOAL:=help

ADDITIONAL_CLEAN=clean_charts
clean_charts:
	rm -rf ${K8S_HELM_RESSOURCES}/charts

include build/make/variables.mk
include build/make/clean.mk
include build/make/release.mk
include build/make/k8s.mk
include build/make/self-update.mk

##@ Chart preparation

.PHONY: helm-chart-lock
helm-chart-lock: ${K8S_HELM_RESSOURCES}/Chart.lock ## Update dependency hashes in the Chart.lock file

${K8S_HELM_RESSOURCES}/Chart.lock: ${BINARY_HELM}
	@cd ${K8S_HELM_RESSOURCES} && helm dependency update
# use "helm dependency build" to create the file if delete

##@ Release

include build/make/k8s-component.mk

.PHONY: lop-idp-release
lop-idp-release: ## Interactively starts the release workflow for lop-idp
	@echo "Starting git flow release..."
	@build/make/release.sh lop-idp
