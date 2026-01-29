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

	keyAccessToken = "access_token"
	keyAPIHost     = "api_host"
	keyOAuthToken  = "oauth_token"
)

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

		data, err := resource.CommonCredentialExtractor(ctx, pc.Spec.Credentials.Source, c, pc.Spec.Credentials.CommonCredentialSelectors)
		if err != nil {
			return ps, errors.Wrap(err, errExtractCredentials)
		}
		creds := map[string]string{}
		if err := json.Unmarshal(data, &creds); err != nil {
			return ps, errors.Wrap(err, errUnmarshalCredentials)
		}

		// Build provider configuration from credentials
		ps.Configuration = map[string]any{}
		if v, ok := creds[keyAccessToken]; ok {
			ps.Configuration[keyAccessToken] = v
		}
		if v, ok := creds[keyAPIHost]; ok {
			ps.Configuration[keyAPIHost] = v
		}
		if v, ok := creds[keyOAuthToken]; ok {
			ps.Configuration[keyOAuthToken] = v
		}

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
