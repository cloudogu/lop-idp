ARTIFACT_ID=k8s-lop-idp
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
include build/make/self-update.mk

##@ Release

include build/make/k8s-component.mk

.PHONY: lop-idp-release
lop-idp-release: ## Interactively starts the release workflow for lop-idp
	@echo "Starting git flow release..."
	@build/make/release.sh lop-idp
