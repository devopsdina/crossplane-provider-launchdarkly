/*
Copyright 2022 Upbound Inc.
*/

// Package config contains the external name configurations for the launchdarkly upjet provider.
package config

import "github.com/crossplane/upjet/v2/pkg/config"

// ExternalNameConfigs contains all external name configurations for this
// provider.
var ExternalNameConfigs = map[string]config.ExternalName{
	// IAM
	"launchdarkly_access_token":      config.IdentifierFromProvider,
	"launchdarkly_custom_role":       config.IdentifierFromProvider,
	"launchdarkly_team":              config.IdentifierFromProvider,
	"launchdarkly_team_member":       config.IdentifierFromProvider,
	"launchdarkly_team_role_mapping": config.IdentifierFromProvider,

	// Project-specific resources
	"launchdarkly_project":                  config.IdentifierFromProvider,
	"launchdarkly_environment":              config.IdentifierFromProvider,
	"launchdarkly_feature_flag":             config.IdentifierFromProvider,
	"launchdarkly_feature_flag_environment": config.IdentifierFromProvider,
	"launchdarkly_segment":                  config.IdentifierFromProvider,
	"launchdarkly_metric":                   config.IdentifierFromProvider,

	// Miscellaneous
	"launchdarkly_audit_log_subscription":    config.IdentifierFromProvider,
	"launchdarkly_destination":               config.IdentifierFromProvider,
	"launchdarkly_webhook":                   config.IdentifierFromProvider,
	"launchdarkly_relay_proxy_configuration": config.IdentifierFromProvider,
}

// ExternalNameConfigurations applies all external name configs listed in the
// table ExternalNameConfigs and sets the version of those resources to v1beta1
// assuming they will be tested.
func ExternalNameConfigurations() config.ResourceOption {
	return func(r *config.Resource) {
		if e, ok := ExternalNameConfigs[r.Name]; ok {
			r.ExternalName = e
		}
	}
}

// PluginFrameworkResources contains resources implemented with Terraform Plugin Framework
// (as opposed to SDK v2). These require different upjet configuration.
var PluginFrameworkResources = map[string]bool{
	"launchdarkly_team_role_mapping": true,
}

// SDKResourcesConfigured returns the list of SDK v2 resources (excludes Plugin Framework resources).
func SDKResourcesConfigured() []string {
	var l []string
	for name := range ExternalNameConfigs {
		if !PluginFrameworkResources[name] {
			// $ is added to match the exact string since the format is regex.
			l = append(l, name+"$")
		}
	}
	return l
}

// FrameworkResourcesConfigured returns the list of Plugin Framework resources.
func FrameworkResourcesConfigured() []string {
	l := make([]string, 0, len(PluginFrameworkResources))
	for name := range PluginFrameworkResources {
		// $ is added to match the exact string since the format is regex.
		l = append(l, name+"$")
	}
	return l
}

// ExternalNameConfigured returns the list of all resources whose external name
// is configured manually.
func ExternalNameConfigured() []string {
	l := make([]string, len(ExternalNameConfigs))
	i := 0
	for name := range ExternalNameConfigs {
		// $ is added to match the exact string since the format is regex.
		l[i] = name + "$"
		i++
	}
	return l
}
