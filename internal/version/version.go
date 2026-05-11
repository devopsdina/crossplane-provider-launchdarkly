/*
Copyright 2026 LaunchDarkly, Inc.
*/

// Package version exposes version strings used by the launchdarkly upjet
// provider. These values are baked into the binary at build time and are
// surfaced to upstream SDKs (e.g. user-agent strings) at runtime.
package version

// Version is the provider's own release version, injected at link time by
// the Makefile via:
//
//	GO_LDFLAGS += -X $(GO_PROJECT)/internal/version.Version=$(VERSION)
//
// MUST be a `var` (not `const`) — the linker's `-X` flag only rewrites
// package-level string variables, not constants. Defaults to "dev" when
// built without ldflags (e.g. `go run ./cmd/provider`, `go test ./...`),
// so the binary always has a sensible value.
var Version = "dev"

// TerraformProviderVersion is the upstream
// github.com/launchdarkly/terraform-provider-launchdarkly release that this
// binary embeds via no-fork mode.
//
// When bumping the upstream provider, keep all of the following in sync —
// they cannot share a single literal because they're consumed by different
// external systems:
//
//   - This constant (passed to ldProvider.NewPluginProvider at runtime).
//   - Makefile: TERRAFORM_PROVIDER_VERSION (Terraform Registry semver,
//     no `v` prefix). Used by `make generate` to dump config/schema.json.
//   - go.mod: the pseudo-version on the github.com/launchdarkly/terraform-
//     provider-launchdarkly line, derived from the release commit SHA via
//     `go mod download <module>@<sha>`.
//   - Makefile (optional): TERRAFORM_PROVIDER_GIT_REF, if pinning docs to
//     the tag instead of tracking main.
//
// See README.md "Architecture > Note on Go Module Dependency" for why a
// pseudo-version is required in go.mod.
const TerraformProviderVersion = "2.29.0"
