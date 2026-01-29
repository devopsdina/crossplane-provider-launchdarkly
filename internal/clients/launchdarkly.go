/*
Copyright 2021 Upbound Inc.
*/

// Package clients contains the clients for the launchdarkly upjet provider.
package clients

import (
	"context"
	"encoding/json"

	"github.com/crossplane/crossplane-runtime/v2/pkg/resource"
	"github.com/pkg/errors"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/crossplane/upjet/v2/pkg/terraform"
	tfsdk "github.com/hashicorp/terraform-plugin-sdk/v2/terraform"
	ldProvider "github.com/launchdarkly/terraform-provider-launchdarkly/launchdarkly"

	"github.com/launchdarkly/crossplane-provider-launchdarkly/apis/v1beta1"
)

const (
	// Provider version for Plugin Framework
	providerVersion = "2.25.3"

	// error messages
	errNotLegacyManaged     = "managed resource does not implement LegacyManaged"
	errNoProviderConfig     = "no providerConfigRef provided"
	errGetProviderConfig    = "cannot get referenced ProviderConfig"
	errTrackUsage           = "cannot track ProviderConfig usage"
	errExtractCredentials   = "cannot extract credentials"
	errUnmarshalCredentials = "cannot unmarshal launchdarkly credentials as JSON"
	errConfigureSDKProvider = "cannot configure LaunchDarkly SDK provider"
)

// credentialKeys are the supported keys in the credentials JSON.
var credentialKeys = []string{"access_token", "api_host", "oauth_token"}

// extractCredentials retrieves and unmarshals credentials from the ProviderConfig.
func extractCredentials(ctx context.Context, c client.Client, pc *v1beta1.ProviderConfig) (map[string]string, error) {
	data, err := resource.CommonCredentialExtractor(ctx, pc.Spec.Credentials.Source, c, pc.Spec.Credentials.CommonCredentialSelectors)
	if err != nil {
		return nil, errors.Wrap(err, errExtractCredentials)
	}
	creds := map[string]string{}
	if err := json.Unmarshal(data, &creds); err != nil {
		return nil, errors.Wrap(err, errUnmarshalCredentials)
	}
	return creds, nil
}

// buildConfiguration creates the provider configuration map from credentials.
func buildConfiguration(creds map[string]string) map[string]any {
	config := map[string]any{}
	for _, key := range credentialKeys {
		if v, ok := creds[key]; ok {
			config[key] = v
		}
	}
	return config
}

// TerraformSetupBuilder returns a SetupFn for no-fork mode.
// This does not require Terraform CLI at runtime - it calls the
// provider's Go code directly for both SDK v2 and Plugin Framework resources.
func TerraformSetupBuilder() terraform.SetupFn {
	return func(ctx context.Context, c client.Client, mg resource.Managed) (terraform.Setup, error) {
		ps := terraform.Setup{}

		lm, ok := mg.(resource.LegacyManaged)
		if !ok {
			return ps, errors.New(errNotLegacyManaged)
		}

		configRef := lm.GetProviderConfigReference()
		if configRef == nil {
			return ps, errors.New(errNoProviderConfig)
		}
		pc := &v1beta1.ProviderConfig{}
		if err := c.Get(ctx, types.NamespacedName{Name: configRef.Name}, pc); err != nil {
			return ps, errors.Wrap(err, errGetProviderConfig)
		}

		t := resource.NewLegacyProviderConfigUsageTracker(c, &v1beta1.ProviderConfigUsage{})
		if err := t.Track(ctx, lm); err != nil {
			return ps, errors.Wrap(err, errTrackUsage)
		}

		creds, err := extractCredentials(ctx, c, pc)
		if err != nil {
			return ps, err
		}

		ps.Configuration = buildConfiguration(creds)

		// Configure SDK v2 provider (for most resources)
		sdkProvider := ldProvider.Provider()
		diags := sdkProvider.Configure(ctx, tfsdk.NewResourceConfigRaw(ps.Configuration))
		if diags.HasError() {
			return ps, errors.Wrap(errors.Errorf("%v", diags), errConfigureSDKProvider)
		}
		ps.Meta = sdkProvider.Meta()

		// Configure Plugin Framework provider (for team_role_mapping)
		ps.FrameworkProvider = ldProvider.NewPluginProvider(providerVersion)()

		return ps, nil
	}
}
