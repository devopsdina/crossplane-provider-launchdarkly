# ====================================================================================
# Setup Project

PROJECT_NAME ?= provider-launchdarkly
PROJECT_REPO ?= github.com/launchdarkly/crossplane-$(PROJECT_NAME)

export TERRAFORM_VERSION ?= 1.5.7

# Do not allow a version of terraform greater than 1.5.x, due to versions 1.6+ being
# licensed under BSL, which is not permitted.
TERRAFORM_VERSION_VALID := $(shell [ "$(TERRAFORM_VERSION)" = "`printf "$(TERRAFORM_VERSION)\n1.6" | sort -V | head -n1`" ] && echo 1 || echo 0)

export TERRAFORM_PROVIDER_SOURCE ?= launchdarkly/launchdarkly
export TERRAFORM_PROVIDER_REPO ?= https://github.com/launchdarkly/terraform-provider-launchdarkly
export TERRAFORM_PROVIDER_VERSION ?= 2.25.3
export TERRAFORM_DOCS_PATH ?= docs/resources


PLATFORMS ?= linux_amd64 linux_arm64

# -include will silently skip missing files, which allows us
# to load those files with a target in the Makefile. If only
# "include" was used, the make command would fail and refuse
# to run a target until the include commands succeeded.
-include build/makelib/common.mk

# ====================================================================================
# Setup Output

-include build/makelib/output.mk

# ====================================================================================
# Setup Go

# Set a sane default so that the nprocs calculation below is less noisy on the initial
# loading of this file
NPROCS ?= 1

# each of our test suites starts a kube-apiserver and running many test suites in
# parallel can lead to high CPU utilization. by default we reduce the parallelism
# to half the number of CPU cores.
GO_TEST_PARALLEL := $(shell echo $$(( $(NPROCS) / 2 )))

GO_REQUIRED_VERSION ?= 1.25
GOLANGCILINT_VERSION ?= 2.8.0
GO_STATIC_PACKAGES = $(GO_PROJECT)/cmd/provider $(GO_PROJECT)/cmd/generator
GO_LDFLAGS += -X $(GO_PROJECT)/internal/version.Version=$(VERSION)
GO_SUBDIRS += cmd internal apis
-include build/makelib/golang.mk

# ====================================================================================
# Setup Kubernetes tools

KIND_VERSION = v0.30.0
UP_VERSION = v0.28.0
UP_CHANNEL = stable
UPTEST_VERSION = v2.2.0
-include build/makelib/k8s_tools.mk

# ====================================================================================
# Setup Images

REGISTRY_ORGS ?= xpkg.upbound.io/launchdarkly
IMAGES = $(PROJECT_NAME)
-include build/makelib/imagelight.mk

# ====================================================================================
# Setup XPKG

XPKG_REG_ORGS ?= xpkg.upbound.io/launchdarkly
# NOTE(hasheddan): skip promoting on xpkg.upbound.io as channel tags are
# inferred.
XPKG_REG_ORGS_NO_PROMOTE ?= xpkg.upbound.io/launchdarkly
XPKGS = $(PROJECT_NAME)
-include build/makelib/xpkg.mk

# ====================================================================================
# Fallthrough

# run `make help` to see the targets and options

# We want submodules to be set up the first time `make` is run.
# We manage the build/ folder and its Makefiles as a submodule.
# The first time `make` is run, the includes of build/*.mk files will
# all fail, and this target will be run. The next time, the default as defined
# by the includes will be run instead.
fallthrough: submodules
	@echo Initial setup complete. Running make again . . .
	@make

# NOTE(hasheddan): we force image building to happen prior to xpkg build so that
# we ensure image is present in daemon.
xpkg.build.provider-launchdarkly: do.build.images

# NOTE: Workaround for crossplane/build bug - ensure CROSSPLANE_CLI is downloaded
# before xpkg build (xpkg.mk doesn't declare it as a prerequisite)
xpkg.build.provider-launchdarkly: $(CROSSPLANE_CLI)

# NOTE(hasheddan): we ensure up is installed prior to running platform-specific
# build steps in parallel to avoid encountering an installation race condition.
build.init: $(UP) $(CROSSPLANE_CLI)

# ====================================================================================
# Setup Terraform for fetching provider schema
TERRAFORM := $(TOOLS_HOST_DIR)/terraform-$(TERRAFORM_VERSION)
TERRAFORM_WORKDIR := $(WORK_DIR)/terraform
TERRAFORM_PROVIDER_SCHEMA := config/schema.json

check-terraform-version:
ifneq ($(TERRAFORM_VERSION_VALID),1)
	$(error invalid TERRAFORM_VERSION $(TERRAFORM_VERSION), must be less than 1.6.0 since that version introduced a not permitted BSL license))
endif

$(TERRAFORM): check-terraform-version
	@$(INFO) installing terraform $(HOSTOS)-$(HOSTARCH)
	@mkdir -p $(TOOLS_HOST_DIR)/tmp-terraform
	@curl -fsSL https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_$(SAFEHOST_PLATFORM).zip -o $(TOOLS_HOST_DIR)/tmp-terraform/terraform.zip
	@unzip $(TOOLS_HOST_DIR)/tmp-terraform/terraform.zip -d $(TOOLS_HOST_DIR)/tmp-terraform
	@mv $(TOOLS_HOST_DIR)/tmp-terraform/terraform $(TERRAFORM)
	@rm -fr $(TOOLS_HOST_DIR)/tmp-terraform
	@$(OK) installing terraform $(HOSTOS)-$(HOSTARCH)

$(TERRAFORM_PROVIDER_SCHEMA): $(TERRAFORM)
	@$(INFO) generating provider schema for $(TERRAFORM_PROVIDER_SOURCE) $(TERRAFORM_PROVIDER_VERSION)
	@mkdir -p $(TERRAFORM_WORKDIR)
	@echo '{"terraform":[{"required_providers":[{"provider":{"source":"'"$(TERRAFORM_PROVIDER_SOURCE)"'","version":"'"$(TERRAFORM_PROVIDER_VERSION)"'"}}],"required_version":"'"$(TERRAFORM_VERSION)"'"}]}' > $(TERRAFORM_WORKDIR)/main.tf.json
	@$(TERRAFORM) -chdir=$(TERRAFORM_WORKDIR) init > $(TERRAFORM_WORKDIR)/terraform-logs.txt 2>&1
	@$(TERRAFORM) -chdir=$(TERRAFORM_WORKDIR) providers schema -json=true > $(TERRAFORM_PROVIDER_SCHEMA) 2>> $(TERRAFORM_WORKDIR)/terraform-logs.txt
	@$(OK) generating provider schema for $(TERRAFORM_PROVIDER_SOURCE) $(TERRAFORM_PROVIDER_VERSION)

pull-docs:
	@if [ ! -d "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" ]; then \
  		mkdir -p "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" && \
		git clone -c advice.detachedHead=false --depth 1 --filter=blob:none --branch "v$(TERRAFORM_PROVIDER_VERSION)" --sparse "$(TERRAFORM_PROVIDER_REPO)" "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)"; \
	fi
	@git -C "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" sparse-checkout set "$(TERRAFORM_DOCS_PATH)"

generate.init: $(TERRAFORM_PROVIDER_SCHEMA) pull-docs

.PHONY: $(TERRAFORM_PROVIDER_SCHEMA) pull-docs check-terraform-version
# ====================================================================================
# Targets

# NOTE: the build submodule currently overrides XDG_CACHE_HOME in order to
# force the Helm 3 to use the .work/helm directory. This causes Go on Linux
# machines to use that directory as the build cache as well. We should adjust
# this behavior in the build submodule because it is also causing Linux users
# to duplicate their build cache, but for now we just make it easier to identify
# its location in CI so that we cache between builds.
go.cachedir:
	@go env GOCACHE

# Generate a coverage report for cobertura applying exclusions on
# - generated file
cobertura:
	@cat $(GO_TEST_OUTPUT)/coverage.txt | \
		grep -v zz_ | \
		$(GOCOVER_COBERTURA) > $(GO_TEST_OUTPUT)/cobertura-coverage.xml

# Update the submodules, such as the common build scripts.
submodules:
	@git submodule sync
	@git submodule update --init --recursive

# This is for running out-of-cluster locally, and is for convenience. Running
# this make target will print out the command which was used. For more control,
# try running the binary directly with different arguments.
run: go.build
	@$(INFO) Running Crossplane locally out-of-cluster . . .
	@# To see other arguments that can be provided, run the command with --help instead
	UPBOUND_CONTEXT="local" $(GO_OUT_DIR)/provider --debug

# ====================================================================================
# End to End Testing
CROSSPLANE_VERSION = 2.0.2
CROSSPLANE_NAMESPACE = upbound-system
-include build/makelib/local.xpkg.mk
-include build/makelib/controlplane.mk

# This target requires the following environment variables to be set:
# - UPTEST_EXAMPLE_LIST, a comma-separated list of examples to test
#   To ensure the proper functioning of the end-to-end test resource pre-deletion hook, it is crucial to arrange your resources appropriately. 
#   You can check the basic implementation here: https://github.com/crossplane/uptest/blob/main/internal/templates/03-delete.yaml.tmpl.
# - UPTEST_CLOUD_CREDENTIALS (optional), multiple sets of AWS IAM User credentials specified as key=value pairs.
#   The support keys are currently `DEFAULT` and `PEER`. So, an example for the value of this env. variable is:
#   DEFAULT='[default]
#   aws_access_key_id = REDACTED
#   aws_secret_access_key = REDACTED'
#   PEER='[default]
#   aws_access_key_id = REDACTED
#   aws_secret_access_key = REDACTED'
#   The associated `ProviderConfig`s will be named as `default` and `peer`.
# - UPTEST_DATASOURCE_PATH (optional), please see https://github.com/crossplane/uptest#injecting-dynamic-values-and-datasource
uptest: $(UPTEST) $(KUBECTL) $(KUTTL)
	@$(INFO) running automated tests
	@KUBECTL=$(KUBECTL) KUTTL=$(KUTTL) $(UPTEST) e2e "${UPTEST_EXAMPLE_LIST}" --data-source="${UPTEST_DATASOURCE_PATH}" --setup-script=cluster/test/setup.sh --default-conditions="Test" || $(FAIL)
	@$(OK) running automated tests

local-deploy: build controlplane.up local.xpkg.deploy.provider.$(PROJECT_NAME)
	@$(INFO) running locally built provider
	@$(KUBECTL) wait provider.pkg $(PROJECT_NAME) --for condition=Healthy --timeout 5m
	@$(KUBECTL) -n upbound-system wait --for=condition=Available deployment --all --timeout=5m
	@$(OK) running locally built provider

e2e: local-deploy uptest

# ====================================================================================
# Local E2E Testing (run the example CRDs against your LaunchDarkly account)
#
# Usage:
#   1. Copy cluster/test/credentials.json.example to cluster/test/credentials.json
#   2. Add your LaunchDarkly API admin token to cluster/test/credentials.json
#   3. Run: make local-e2e
#
# Or run steps individually:
#   make local-e2e-setup    - Create secret and ProviderConfig in cluster
#   make local-e2e-create   - Apply all test resources to LaunchDarkly
#   make local-e2e-verify   - Wait for resources to be Ready
#   make local-e2e-cleanup  - Delete all test resources from LaunchDarkly

LOCAL_E2E_CREDS_FILE ?= cluster/test/credentials.json
LOCAL_E2E_EXAMPLES ?= examples/project_environment_and_flag

# Setup credentials from local file
local-e2e-setup:
	@$(INFO) Setting up credentials from $(LOCAL_E2E_CREDS_FILE)
	@test -f $(LOCAL_E2E_CREDS_FILE) || (echo "ERROR: $(LOCAL_E2E_CREDS_FILE) not found. Copy from credentials.json.example and add your API token" && exit 1)
	@$(KUBECTL) -n $(CROSSPLANE_NAMESPACE) create secret generic provider-secret \
		--from-file=credentials=$(LOCAL_E2E_CREDS_FILE) \
		--dry-run=client -o yaml | $(KUBECTL) apply -f -
	@$(KUBECTL) apply -f cluster/test/providerconfig.yaml
	@$(OK) Credentials configured

# Create ALL test resources in LaunchDarkly
# Skips: destination/kinesis.yaml (AWS), auditlogsubscription/datadog.yaml (Datadog)
local-e2e-create:
	@$(INFO) Creating ALL test resources in LaunchDarkly
	@echo ""
	@echo "=== Phase 1: Independent resources (no dependencies) ==="
	@echo "Creating custom roles..."
	@$(KUBECTL) apply -f examples/custom_role/custom_role.yaml
	@echo "Creating webhook..."
	@$(KUBECTL) apply -f examples/webhook/webhook.yaml
	@echo "Creating access token..."
	@$(KUBECTL) apply -f examples/access_token/access_token.yaml
	@echo "Creating relay proxy configuration..."
	@$(KUBECTL) apply -f examples/relay_proxy_configuration/relay_proxy_configuration.yaml
	@sleep 2
	@echo ""
	@echo "=== Phase 2: Project and environments ==="
	@$(KUBECTL) apply -f $(LOCAL_E2E_EXAMPLES)/project_environment.yaml
	@sleep 3
	@echo ""
	@echo "=== Phase 3: Team members (before team) ==="
	@$(KUBECTL) apply -f examples/team_with_custom_roles/members.yml
	@sleep 2
	@echo ""
	@echo "=== Phase 4: Team with custom roles ==="
	@$(KUBECTL) apply -f examples/team_with_custom_roles/team.yaml
	@sleep 2
	@echo ""
	@echo "=== Phase 5: Feature flags (all types) ==="
	@$(KUBECTL) apply -f $(LOCAL_E2E_EXAMPLES)/flag.yaml
	@$(KUBECTL) apply -f examples/feature_flag/boolean.yaml
	@$(KUBECTL) apply -f examples/feature_flag/json.yaml
	@$(KUBECTL) apply -f examples/feature_flag/number.yaml
	@$(KUBECTL) apply -f examples/feature_flag/string.yaml
	@$(KUBECTL) apply -f examples/feature_flag_environment/targeting.yaml
	@sleep 2
	@echo ""
	@echo "=== Phase 6: Segments ==="
	@$(KUBECTL) apply -f $(LOCAL_E2E_EXAMPLES)/segment.yaml
	@$(KUBECTL) apply -f examples/segment/segment.yaml
	@echo ""
	@$(OK) All test resources created

# Wait for all resources to be Ready (with fast failure detection)
local-e2e-verify:
	@$(INFO) Waiting for resources to be Ready - up to 2 minutes
	@echo ""
	@echo "Giving resources time to reconcile..."
	@sleep 10
	@echo ""
	@echo "=== Waiting for all resources (2 minute timeout) ==="
	@$(KUBECTL) wait --for=condition=Ready customrole --all --timeout=2m 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=Ready webhook --all --timeout=30s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=Ready accesstoken --all --timeout=30s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=Ready relayproxyconfiguration --all --timeout=30s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=Ready project --all --timeout=30s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=Ready environment --all --timeout=30s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=Ready teammember --all --timeout=30s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=Ready team --all --timeout=30s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=Ready featureflag --all --timeout=30s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=Ready featureflagenvironment --all --timeout=30s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=Ready environmentsegment --all --timeout=30s 2>/dev/null || true
	@echo ""
	@$(MAKE) local-e2e-check-failures
	@$(OK) All resources Ready

# Cleanup ALL test resources (reverse dependency order)
local-e2e-cleanup:
	@$(INFO) Cleaning up ALL test resources from LaunchDarkly
	@echo ""
	@echo "=== Phase 1: Segments ==="
	@$(KUBECTL) delete -f examples/segment/segment.yaml --ignore-not-found --wait=true || true
	@$(KUBECTL) delete -f $(LOCAL_E2E_EXAMPLES)/segment.yaml --ignore-not-found --wait=true || true
	@echo ""
	@echo "=== Phase 2: Feature flag environments ==="
	@$(KUBECTL) delete featureflagenvironment --all --ignore-not-found --wait=true || true
	@echo ""
	@echo "=== Phase 3: Feature flags ==="
	@$(KUBECTL) delete -f examples/feature_flag_environment/targeting.yaml --ignore-not-found --wait=true || true
	@$(KUBECTL) delete -f examples/feature_flag/string.yaml --ignore-not-found --wait=true || true
	@$(KUBECTL) delete -f examples/feature_flag/number.yaml --ignore-not-found --wait=true || true
	@$(KUBECTL) delete -f examples/feature_flag/json.yaml --ignore-not-found --wait=true || true
	@$(KUBECTL) delete -f examples/feature_flag/boolean.yaml --ignore-not-found --wait=true || true
	@$(KUBECTL) delete -f $(LOCAL_E2E_EXAMPLES)/flag.yaml --ignore-not-found --wait=true || true
	@echo ""
	@echo "=== Phase 4: Team ==="
	@$(KUBECTL) delete -f examples/team_with_custom_roles/team.yaml --ignore-not-found --wait=true || true
	@echo ""
	@echo "=== Phase 5: Team members ==="
	@$(KUBECTL) delete -f examples/team_with_custom_roles/members.yml --ignore-not-found --wait=true || true
	@echo ""
	@echo "=== Phase 6: Project and environments ==="
	@$(KUBECTL) delete -f $(LOCAL_E2E_EXAMPLES)/project_environment.yaml --ignore-not-found --wait=true || true
	@echo ""
	@echo "=== Phase 7: Independent resources ==="
	@$(KUBECTL) delete -f examples/relay_proxy_configuration/relay_proxy_configuration.yaml --ignore-not-found --wait=true || true
	@$(KUBECTL) delete -f examples/access_token/access_token.yaml --ignore-not-found --wait=true || true
	@$(KUBECTL) delete -f examples/webhook/webhook.yaml --ignore-not-found --wait=true || true
	@$(KUBECTL) delete -f examples/custom_role/custom_role.yaml --ignore-not-found --wait=true || true
	@echo ""
	@$(OK) All test resources cleaned up

# Check for failed resources and provide detailed error summary
# This target scans all Crossplane managed resources for failures and reports them clearly
local-e2e-check-failures:
	@echo ""
	@echo "=== E2E Test Failure Summary ==="
	@FAILED=0; \
	PANIC_COUNT=0; \
	NO_STATUS_COUNT=0; \
	DEP_COUNT=0; \
	API_COUNT=0; \
	echo ""; \
	for kind in customrole accesstoken webhook relayproxyconfiguration project environment teammember team featureflag featureflagenvironment environmentsegment; do \
		RESOURCES=$$($(KUBECTL) get $$kind -o name 2>/dev/null); \
		for resource in $$RESOURCES; do \
			SYNCED=$$($(KUBECTL) get $$resource -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null); \
			READY=$$($(KUBECTL) get $$resource -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null); \
			if [ "$$SYNCED" = "False" ] || [ "$$READY" = "False" ]; then \
				FAILED=$$((FAILED + 1)); \
				MESSAGE=$$($(KUBECTL) get $$resource -o jsonpath='{.status.conditions[?(@.type=="Synced")].message}' 2>/dev/null); \
				if [ -z "$$MESSAGE" ]; then \
					MESSAGE=$$($(KUBECTL) get $$resource -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null); \
				fi; \
				printf "\033[31m"; \
				echo "❌ $$resource"; \
				printf "\033[0m"; \
				echo "   Status: Synced=$$SYNCED, Ready=$$READY"; \
				if echo "$$MESSAGE" | grep -q "panic"; then \
					PANIC_COUNT=$$((PANIC_COUNT + 1)); \
					echo "   Message: $$MESSAGE"; \
					printf "\033[33m"; \
					echo "   Cause: Upstream Terraform provider bug - no-fork mode compatibility"; \
					printf "\033[0m"; \
				elif echo "$$MESSAGE" | grep -q "referenced field was empty"; then \
					DEP_COUNT=$$((DEP_COUNT + 1)); \
					echo "   Message: $$MESSAGE"; \
					echo "   Cause: Waiting for dependency to be ready"; \
				else \
					API_COUNT=$$((API_COUNT + 1)); \
					echo "   Message: $$MESSAGE"; \
				fi; \
				echo ""; \
			elif [ -z "$$SYNCED" ] && [ -z "$$READY" ]; then \
				FAILED=$$((FAILED + 1)); \
				NO_STATUS_COUNT=$$((NO_STATUS_COUNT + 1)); \
				printf "\033[31m"; \
				echo "❌ $$resource"; \
				printf "\033[0m"; \
				printf "\033[33m"; \
				echo "   Status: No conditions - controller may not have processed this resource"; \
				echo "   Cause: Resource may be failing silently or controller is not running"; \
				printf "\033[0m"; \
				echo ""; \
			fi; \
		done; \
	done; \
	echo ""; \
	echo "=== Checking Kubernetes Warning Events ==="; \
	WARNINGS=$$($(KUBECTL) get events --field-selector type=Warning -o custom-columns='NAME:.involvedObject.name,KIND:.involvedObject.kind,MESSAGE:.message' 2>/dev/null | grep -iE "customrole|accesstoken|webhook|relayproxy|project|environment|teammember|team|featureflag|segment" | head -10); \
	if [ -n "$$WARNINGS" ]; then \
		printf "\033[33m"; \
		echo "$$WARNINGS"; \
		printf "\033[0m"; \
	else \
		echo "No warning events found for managed resources."; \
	fi; \
	echo ""; \
	if [ $$FAILED -gt 0 ]; then \
		printf "\033[31m"; \
		echo "=== RESULT: $$FAILED resource(s) failed ==="; \
		printf "\033[0m"; \
		echo ""; \
		echo "Breakdown:"; \
		if [ $$PANIC_COUNT -gt 0 ]; then \
			printf "\033[33m"; \
			echo "  - $$PANIC_COUNT Terraform provider panic(s) - ROOT CAUSE"; \
			printf "\033[0m"; \
		fi; \
		if [ $$NO_STATUS_COUNT -gt 0 ]; then \
			printf "\033[33m"; \
			echo "  - $$NO_STATUS_COUNT resource(s) with no status - may also be panicking"; \
			printf "\033[0m"; \
		fi; \
		if [ $$DEP_COUNT -gt 0 ]; then \
			echo "  - $$DEP_COUNT dependency resolution failure(s) - cascading"; \
		fi; \
		if [ $$API_COUNT -gt 0 ]; then \
			echo "  - $$API_COUNT API/other error(s) - likely cascading"; \
		fi; \
		if [ $$PANIC_COUNT -gt 0 ] || [ $$NO_STATUS_COUNT -gt 0 ]; then \
			printf "\033[33m"; \
			echo ""; \
			echo "⚠️  Root cause: Upstream Terraform provider compatibility issue."; \
			echo "   This is a known issue with Upjet no-fork mode."; \
			echo "   See: https://github.com/launchdarkly/terraform-provider-launchdarkly"; \
			echo ""; \
			echo "   The other failures are cascading - when parent resources fail,"; \
			echo "   dependent resources also fail due to unresolved references."; \
			printf "\033[0m"; \
		fi; \
		exit 1; \
	else \
		printf "\033[32m"; \
		echo "=== RESULT: All resources healthy ==="; \
		printf "\033[0m"; \
	fi

# Full local e2e workflow: deploy provider, setup creds, create resources, verify
local-e2e: local-deploy local-e2e-setup local-e2e-create local-e2e-verify
	@$(INFO) Local E2E test complete - resources created in LaunchDarkly
	@echo "Run 'make local-e2e-cleanup' to delete test resources"

.PHONY: local-e2e-setup local-e2e-create local-e2e-verify local-e2e-check-failures local-e2e-cleanup local-e2e-cleanup-force local-e2e

crddiff: $(UPTEST)
	@$(INFO) Checking breaking CRD schema changes
	@for crd in $${MODIFIED_CRD_LIST}; do \
		if ! git cat-file -e "$${GITHUB_BASE_REF}:$${crd}" 2>/dev/null; then \
			echo "CRD $${crd} does not exist in the $${GITHUB_BASE_REF} branch. Skipping..." ; \
			continue ; \
		fi ; \
		echo "Checking $${crd} for breaking API changes..." ; \
		changes_detected=$$($(UPTEST) crddiff revision <(git cat-file -p "$${GITHUB_BASE_REF}:$${crd}") "$${crd}" 2>&1) ; \
		if [[ $$? != 0 ]] ; then \
			printf "\033[31m"; echo "Breaking change detected!"; printf "\033[0m" ; \
			echo "$${changes_detected}" ; \
			echo ; \
		fi ; \
	done
	@$(OK) Checking breaking CRD schema changes

schema-version-diff:
	@$(INFO) Checking for native state schema version changes
	@export PREV_PROVIDER_VERSION=$$(git cat-file -p "${GITHUB_BASE_REF}:Makefile" | sed -nr 's/^export[[:space:]]*TERRAFORM_PROVIDER_VERSION[[:space:]]*:=[[:space:]]*(.+)/\1/p'); \
	echo Detected previous Terraform provider version: $${PREV_PROVIDER_VERSION}; \
	echo Current Terraform provider version: $${TERRAFORM_PROVIDER_VERSION}; \
	mkdir -p $(WORK_DIR); \
	git cat-file -p "$${GITHUB_BASE_REF}:config/schema.json" > "$(WORK_DIR)/schema.json.$${PREV_PROVIDER_VERSION}"; \
	./scripts/version_diff.py config/generated.lst "$(WORK_DIR)/schema.json.$${PREV_PROVIDER_VERSION}" config/schema.json
	@$(OK) Checking for native state schema version changes

.PHONY: cobertura submodules fallthrough run crds.clean

# ====================================================================================
# Special Targets

define CROSSPLANE_MAKE_HELP
Crossplane Targets:
    cobertura             Generate a coverage report for cobertura applying exclusions on generated files.
    submodules            Update the submodules, such as the common build scripts.
    run                   Run crossplane locally, out-of-cluster. Useful for development.

endef
# The reason CROSSPLANE_MAKE_HELP is used instead of CROSSPLANE_HELP is because the crossplane
# binary will try to use CROSSPLANE_HELP if it is set, and this is for something different.
export CROSSPLANE_MAKE_HELP

crossplane.help:
	@echo "$$CROSSPLANE_MAKE_HELP"

help-special: crossplane.help

.PHONY: crossplane.help help-special

# TODO(negz): Update CI to use these targets.
vendor: modules.download
vendor.check: modules.check
