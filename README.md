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
up ctp provider install xpkg.upbound.io/launchdarkly/provider-launchdarkly:v0.6.0
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
  package: xpkg.upbound.io/launchdarkly/provider-launchdarkly:v0.6.0
EOF
```

<!-- x-release-please-end -->

Notice that in this example Provider resource is referencing ControllerConfig with debug enabled.

You can see the API reference [here](https://doc.crds.dev/github.com/launchdarkly/crossplane-provider-launchdarkly).


## Architecture

This provider uses Upjet's **no-fork mode**, which means it directly imports and calls the LaunchDarkly Terraform provider's Go SDK rather than spawning Terraform CLI as a subprocess.

**Note on Go Module Dependency:**

Currently, the LaunchDarkly Terraform provider (`github.com/launchdarkly/terraform-provider-launchdarkly`) does not follow Go module versioning conventions for v2+ releases (missing `/v2` suffix in the module path). As a result, we must use a **pseudo-version** (commit hash) instead of a semantic version tag.


When updating the Terraform provider dependency, you'll need to:

1. Find the commit hash for the desired release tag
2. Generate the pseudo-version using: `go mod download github.com/launchdarkly/terraform-provider-launchdarkly@<commit-hash>`
3. Update `go.mod` with the resulting pseudo-version


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

## Report a Bug

For filing bugs, suggesting improvements, or requesting new features, please
open an [issue](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues).
