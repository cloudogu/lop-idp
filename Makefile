ARTIFACT_ID=lop-idp
MAKEFILES_VERSION=10.8.0
VERSION=0.1.0

.DEFAULT_GOAL:=help
ADDITIONAL_CLEAN=clean_charts
K8S_HELM_RESSOURCES=k8s/helm

include build/make/variables.mk
include build/make/clean.mk
include build/make/release.mk
include build/make/k8s-component.mk
include build/make/self-update.mk

clean_charts:
	rm -rf ${K8S_HELM_RESSOURCES}/charts

##@ Release

.PHONY: lop-idp-release
lop-idp-release: ## Interactively starts the release workflow for lop-idp
	@echo "Starting git flow release..."
	@build/make/release.sh lop-idp
