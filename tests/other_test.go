// Tests in this file are NOT run in the PR pipeline. They are run in the continuous testing pipeline along with the ones in pr_test.go
package test

import (
	"context"
	"testing"

	"github.com/IBM/go-sdk-core/v5/core"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/cloudinfo"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testaddons"
)

func TestRunBasicExample(t *testing.T) {
	t.Parallel()
	acquireTestSlot()
	defer releaseTestSlot()

	options := setupOptions(t, basicExampleTerraformDir, "slz-vsi-basic")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

/*
* TEST NOTE: due to potential increased charges of both using catalog offering images and using Gen2 storage,
*   these next tests are in the "other" category to only run on weekly scheduled tests.
 */

func TestRunCatalogImageExample(t *testing.T) {
	t.Parallel()
	acquireTestSlot()
	defer releaseTestSlot()

	options := setupOptions(t, catalogImageExampleTerraformDir, "slz-vsi-cat")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestRunGen2BootExample(t *testing.T) {
	t.Parallel()
	acquireTestSlot()
	defer releaseTestSlot()

	options := setupOptions(t, gen2bootExampleTerraformDir, "slz-vsi-gen2")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestAddonDefaultConfiguration(t *testing.T) {
	t.Parallel()
	acquireTestSlot()
	defer releaseTestSlot()

	// run this terraform code to return the latest ubuntu image ID
	prefix, existingTerraformOptions, existErr := provisionPreReq(t, false)

	if existErr != nil {
		assert.True(t, existErr == nil, "Init and Apply of prereq script failed.")
	} else {

		options := testaddons.TestAddonsOptionsDefault(&testaddons.TestAddonOptions{
			Testing:               t,
			Prefix:                prefix,
			ResourceGroup:         resourceGroup,
			OverrideInputMappings: core.BoolPtr(true),
			QuietMode:             false, // Suppress logs except on failure
		})

		options.AddonConfig = cloudinfo.NewAddonConfigTerraform(
			options.Prefix,
			"deploy-arch-ibm-slz-vsi",
			"fully-configurable",
			map[string]interface{}{
				"region":   terraform.OutputContext(t, context.Background(), existingTerraformOptions, "region"),
				"image_id": terraform.OutputContext(t, context.Background(), existingTerraformOptions, "image_id"),
			},
		)

		//	use existing secrets manager instance to help prevent hitting trial instance limit in account
		options.AddonConfig.Dependencies = []cloudinfo.AddonConfig{
			{
				OfferingName:   "deploy-arch-ibm-secrets-manager",
				OfferingFlavor: "fully-configurable",
				Inputs: map[string]interface{}{
					"existing_secrets_manager_crn":         permanentResources["privateOnlySecMgrCRN"],
					"service_plan":                         "__NULL__", // no plan value needed when using existing SM
					"skip_secrets_manager_iam_auth_policy": true,       // since using an existing Secrets Manager instance, attempting to re-create auth policy can cause conflicts if the policy already exists
					"secret_groups":                        []string{}, // passing empty array for secret groups as default value is creating general group and it will cause conflicts as we are using an existing SM
				},
			},
			// Disable target / route creation to help prevent hitting quota in account
			{
				OfferingName:   "deploy-arch-ibm-cloud-monitoring",
				OfferingFlavor: "fully-configurable",
				Inputs: map[string]interface{}{
					"enable_metrics_routing_to_cloud_monitoring": false,
				},
			},
			{
				OfferingName:   "deploy-arch-ibm-activity-tracker",
				OfferingFlavor: "fully-configurable",
				Inputs: map[string]interface{}{
					"enable_activity_tracker_event_routing_to_cloud_logs": false,
				},
				Enabled: core.BoolPtr(true),
			},
			{
				OfferingName:   "deploy-arch-ibm-scc-workload-protection",
				OfferingFlavor: "fully-configurable",
				Inputs: map[string]interface{}{
					"app_config_crn": permanentResources["app_config_crn"],
				},
				Enabled: core.BoolPtr(true),
			},
		}

		err := options.RunAddonTest()
		require.NoError(t, err)
	}
}
