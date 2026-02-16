# Changelog

## [0.7.0](https://github.com/launchdarkly/crossplane-provider-launchdarkly/compare/v0.6.0...v0.7.0) (2026-02-05)


### Features

* Migrate Crossplane architecture to no-fork mode, remediate critical and high CVEs, add local e2e testing ([#56](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/56)) ([1cc8c4c](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/1cc8c4cdf383ecf7ceb17c47be263fe4a7d495ef))

## [0.6.0](https://github.com/launchdarkly/crossplane-provider-launchdarkly/compare/v0.5.0...v0.6.0) (2026-01-28)


### Features

* Update the crossplane provider to 2.0 using Go 1.25 ([#55](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/55)) ([fc36d7a](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/fc36d7a2d3ca589b9da375d3c0b93f8babc80d2d))
* Bump terraform provider to version 2.25.3 ([#46](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/46)) ([4c2f532](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/4c2f53253032948c889363e702b69d1d703ddabd))
* Bump terraform provider to version 2.25.2 ([#45](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/45)) ([3a2cd22](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/3a2cd228f87b696f2b9ca6de17614fcf1c98d374))

## [0.5.0](https://github.com/launchdarkly/crossplane-provider-launchdarkly/compare/v0.4.0...v0.5.0) (2026-01-28)


### Features

* [REL-8393] add metric resource ([#44](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/44)) ([eb6ffb8](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/eb6ffb8d93e2756837dc57a353783834eecb96d1))
* Bump terraform provider to version 2.25.1 ([#42](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/42)) ([fb6a646](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/fb6a6469f4498c10ce84d47d4a042ae5d5a0c745))

## [0.4.0](https://github.com/launchdarkly/crossplane-provider-launchdarkly/compare/v0.3.0...v0.4.0) (2025-03-20)


### Features

* Bump terraform provider to version 2.25.0 to add support for PagerDuty integration ([#41](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/41)) ([bdf7fe1](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/bdf7fe146a38c582083c97e2d37eb03fa167ae56))


### Bug Fixes

* Update golang.org/x/net and github.com/crossplane/upjet dependencies ([#38](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/38)) ([14df50f](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/14df50f6370388371b914c93afa7e121c4434edf))

## [0.3.0](https://github.com/launchdarkly/crossplane-provider-launchdarkly/compare/v0.2.1...v0.3.0) (2025-03-14)


### Features

* Add cross-resource definitions for AccessToken and EnvironmentDestination resource ([60a3172](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/60a31724a6ba629d1e3c70ad112163c14c241ca3))
* Add cross-resource definitions for AccessToken and EnvironmentDestination resources ([#32](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/32)) ([60a3172](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/60a31724a6ba629d1e3c70ad112163c14c241ca3))
* Add RelayProxyConfiguration resource ([#33](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/33)) ([87ab99f](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/87ab99f39664e8b86ed430a9d84853bc72c8d3d1))

## [0.2.1](https://github.com/launchdarkly/crossplane-provider-launchdarkly/compare/v0.2.0...v0.2.1) (2025-03-12)


### Bug Fixes

* revert publish-artifacts job refactor ([#28](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/28)) ([27892b6](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/27892b6e7c01ec7cbf2914819604a6134b11557f))

## [0.2.0](https://github.com/launchdarkly/crossplane-provider-launchdarkly/compare/v0.1.1...v0.2.0) (2025-03-12)


### Features

* Add cross-resource references to Team resource ([#19](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/19)) ([1c8a31b](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/1c8a31bb9b8b2b20bcc2cfd660de111c3a455e41))
* Add env_key and flag_id cross-resource references on FeatureFlagEnvironment resource ([#17](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/17)) ([6143f81](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/6143f81748e0064cba93791b6eb2bb9996f0708d))
* Add projectKey reference to EnviroknmentSegment resource ([1e8f431](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/1e8f431ce749919c8ee9d6043d21c8ced2e903ac))
* Add projectKey reference to EnvironmentSegment resource ([#18](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/18)) ([1e8f431](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/1e8f431ce749919c8ee9d6043d21c8ced2e903ac))


### Bug Fixes

* resolve issues in extra-files section of release-please-config.json ([#24](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/24)) ([0547945](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/05479457a07395e24294a8b890b70e2e0d51e63f))
* Update env_key and flag_id cross-resource reference on FeatureFlagEnvironment resource ([6143f81](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/6143f81748e0064cba93791b6eb2bb9996f0708d))
* Update project_key cross-resource definition on FeatureFlag resource ([#16](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/16)) ([0167f0b](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/0167f0b380866fc81e69ca46966dae4d428a7e35))
* Update project_key cross-resource reference on Environment resource ([#15](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/15)) ([585d875](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/585d8757ffa587123e2d9b5abd1041f4a2186a35))
* Update project_key cross-resource reference on FeatureFlag resource ([0167f0b](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/0167f0b380866fc81e69ca46966dae4d428a7e35))
* Update Terraform Provider bump action to use semantic PR title ([#23](https://github.com/launchdarkly/crossplane-provider-launchdarkly/issues/23)) ([caeb3e4](https://github.com/launchdarkly/crossplane-provider-launchdarkly/commit/caeb3e470254b779ceca595e9c1fa8f74f95cef3))

## Change log

All notable changes to the LaunchDarkly Terraform Provider will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org).
