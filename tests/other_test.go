// Tests in this file are NOT run in the PR pipeline. They are run in the continuous testing pipeline along with the ones in pr_test.go
package test

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
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

func TestRunReinitializeExample(t *testing.T) {
	t.Parallel()
	acquireTestSlot()
	defer releaseTestSlot()

	options := setupOptions(t, basicExampleTerraformDir, "slz-vsi-reinit")

	// PostApplyHook to reinitialize the instance after initial provisioning
	options.PostApplyHook = func(options *testhelper.TestOptions) error {
		// Get outputs from initial apply to obtain the provisioned image ID
		initialOutputs, err := terraform.OutputAllContextE(options.Testing, context.Background(), options.TerraformOptions)
		if err != nil {
			return err
		}

		imageId, _ := initialOutputs["image_id"].(string)

		// Update the generated tfvars.json file with reinitialization configuration
		if len(options.TerraformOptions.VarFiles) > 0 {
			varFile := options.TerraformOptions.VarFiles[0]
			fileData, err := os.ReadFile(varFile)
			if err != nil {
				return err
			}
			var tfVars map[string]interface{}
			if err := json.Unmarshal(fileData, &tfVars); err != nil {
				return err
			}
			tfVars["reinitialize"] = map[string]interface{}{
				"image":     imageId,
				"user_data": "#!/bin/bash\necho reinitialized > /tmp/reinit.log",
			}
			updatedJson, err := json.MarshalIndent(tfVars, "", "  ")
			if err != nil {
				return err
			}
			if err := os.WriteFile(varFile, updatedJson, 0644); err != nil {
				return err
			}
		}

		// Ensure CLI vars map is nil so terraform reads from var-file
		options.TerraformOptions.Vars = nil

		// Re-apply to trigger reinitialization
		_, err = terraform.ApplyContextE(options.Testing, context.Background(), options.TerraformOptions)
		if err != nil {
			return err
		}

		// Verify reinitialize_status output is populated
		outputs, outputErr := terraform.OutputAllContextE(options.Testing, context.Background(), options.TerraformOptions)
		if outputErr != nil {
			return outputErr
		}

		slzVsi, ok := outputs["slz_vsi"].(map[string]interface{})
		if !ok {
			return fmt.Errorf("expected slz_vsi output map")
		}

		reinitStatus, ok := slzVsi["reinitialize_status"].(map[string]interface{})
		if !ok || len(reinitStatus) == 0 {
			return fmt.Errorf("expected non-empty reinitialize_status in slz_vsi outputs, got: %v", reinitStatus)
		}

		return nil
	}

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
