# Provider LaunchDarkly

`provider-launchdarkly` is a [Crossplane](https://crossplane.io/) provider that
is built using [Upjet](https://github.com/crossplane/upjet) code
generation tools and exposes XRM-conformant managed resources for the
LaunchDarkly API.

## Getting Started

Install the provider by using the following command after changing the image tag
to the [latest release](https://marketplace.upbound.io/providers/launchdarkly/provider-launchdarkly):

<!-- x-release-please-start-version -->

```
up ctp provider install xpkg.upbound.io/launchdarkly/provider-launchdarkly:v0.8.0
```

<!-- x-release-please-end -->

Alternatively, you can use declarative installation:

<!-- x-release-please-start-version -->

```
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-launchdarkly
spec:
  package: xpkg.upbound.io/launchdarkly/provider-launchdarkly:v0.8.0
EOF
```

<!-- x-release-please-end -->

Notice that in this example Provider resource is referencing ControllerConfig with debug enabled.

You can see the API reference [here](https://doc.crds.dev/github.com/launchdarkly/crossplane-provider-launchdarkly).


## Architecture

This provider uses Upjet's **no-fork mode**, which means it directly imports and calls the LaunchDarkly Terraform provider's Go SDK rather than spawning Terraform CLI as a subprocess.

**Note on Go Module Dependency:**
The upstream LaunchDarkly Terraform provider
(`github.com/launchdarkly/terraform-provider-launchdarkly`) is tagged with
`v2.x.x` releases, but its module path does not include the `/v2` suffix that
Go modules requires for v2+ releases ([Semantic Import
Versioning](https://go.dev/ref/mod#major-version-suffixes)). The Go toolchain
therefore refuses to resolve `v2.x.x` tags directly, so this repo pins the
dependency via a Go **pseudo-version** (`vX.Y.Z-0.<timestamp>-<commit12>`)
derived from the release commit. The human-readable release name lives in
three other places — see
[Upgrading the upstream Terraform provider](#upgrading-the-upstream-terraform-provider).
## Upgrading the upstream Terraform provider
> **TL;DR:** Bump *one* Go constant (`internal/version/version.go`), the
> Makefile semver, and the `go.mod` pseudo-version. Then `make generate`.
The provider version is referenced in four distinct places, in three
different formats, because each one is consumed by a different external
system:

| Location | Format | Consumer |
| --- | --- | --- |
| `internal/version/version.go` (`TerraformProviderVersion`) | Bare semver (`"2.29.0"`) | Compiled into the binary; passed to the upstream SDK at runtime |
| `go.mod` line above `terraform-provider-launchdarkly` | Bare semver in a comment | Humans / reviewers |
| `go.mod` `terraform-provider-launchdarkly` line | Go pseudo-version (`v1.7.2-0.<ts>-<sha12>`) | Go module resolver |
| `Makefile` `TERRAFORM_PROVIDER_VERSION` | Terraform Registry semver (no `v` prefix) | Terraform CLI during `make generate` |
`internal/version/version.go` is the single Go-side source of truth — both
`internal/clients/launchdarkly.go` and `config/provider.go` import it, so
runtime callers all read the same constant.

### Step-by-step
1. **Identify the target release** on
   <https://github.com/launchdarkly/terraform-provider-launchdarkly/releases>.
   Note the tag (e.g. `v2.29.0`) and the short commit SHA shown on the
   release page (e.g. `e990d60`).
2. **Compute the canonical Go pseudo-version** for that commit. Run these
   from outside the repo (or from any directory whose `go.mod` does not
   contain a `replace` directive that intercepts the lookup):
   ```bash
   go mod download -x github.com/launchdarkly/terraform-provider-launchdarkly@<sha>
   go list -m github.com/launchdarkly/terraform-provider-launchdarkly


## Developing

### Initial setup

```bash
make submodules
```

Run code-generation pipeline:

```console
make generate
```

Run against a Kubernetes cluster:

```console
make run
```

Build, push, and install:

```console
make all
```

Build binary:

```console
make build
```

### Installing Provider/CRDs into your local k8s cluster

1. Ensure Crossplane is installed on your local cluster (instructions [here](https://docs.crossplane.io/latest/software/install/))
2. Run the following:

   ```bash
   kubectl config use-context <name-of-your-local-k8s-context>
   kubectl apply -f ./package/crds
   ```

### Local End-to-End Testing

Run the `examples/*` folder against your LaunchDarkly account:

1. Set up credentials:
   - `cp cluster/test/credentials.json.example cluster/test/credentials.json`
   - Edit credentials.json with your LaunchDarkly admin API token
   - This step can also be validated separately by running `make local-e2e-setup`

2. Run `make local-e2e`, which will:
    - Deploy the provider to a local Kind cluster
    - Create a secret and ProviderConfig from your admin credentials
    - Apply all example resources (projects, flags, teams, etc.)
    - Wait for all resources to reach Ready state

3. Perform any required manual validation or testing

4. To clean up run `make local-e2e-cleanup`


### Testing Against an Upstream Terraform Provider Branch
To test against a feature branch or unmerged PR on the terraform provider before it ships, without modifying any committed files:
1. Clone the terraform provider and check out the branch you want to test:
   ```bash
   git clone https://github.com/launchdarkly/terraform-provider-launchdarkly ../terraform-provider-launchdarkly
   cd ../terraform-provider-launchdarkly && git checkout issue-387
   ```
2. Create `local.env` in the repo root (gitignored) with the path to your checkout:
   ```
   TF_PROVIDER_PATH = ../terraform-provider-launchdarkly
   ```
3. Run `make local-e2e` as normal. It will:
   - Auto-create `go.work` pointing to your local checkout so the build uses that code
   - Derive `TERRAFORM_PROVIDER_GIT_REF` from whichever branch is checked out
   - Print a banner at the start showing the active path, branch, and commit
   To switch branches, just `git checkout <branch>` in the terraform provider directory — no config changes needed.
4. To go back to the pinned upstream version, delete `local.env` and run `make dev-provider-reset`:
   ```bash
   rm local.env
   make dev-provider-reset
   ```
The banner printed at the start of `make local-e2e` always shows which source is active:
- **Yellow** — local workspace (`local.env` present, using your checkout)
- **Green** — pinned upstream version from `go.mod`

## Report a Bug

For filing bugs, suggesting improvements, or requesting new features, please
open an [issue](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues).
