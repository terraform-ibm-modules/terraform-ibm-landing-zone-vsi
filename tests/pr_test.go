package test

import (
	"log"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

const basicExampleTerraformDir = "examples/basic"
const completeExampleTerraformDir = "examples/complete"
const fsCloudExampleTerraformDir = "examples/fscloud"
const snapshotExampleTerraformDir = "examples/snapshot"

const resourceGroup = "geretain-test-resources"
const region = "us-south"

// Define a struct with fields that match the structure of the YAML data
const yamlLocation = "../common-dev-assets/common-go-assets/common-permanent-resources.yaml"

var permanentResources map[string]interface{}

// TestMain will be run before any parallel tests, used to read data from yaml for use with tests
func TestMain(m *testing.M) {
	// Read the YAML file contents
	var err error
	permanentResources, err = common.LoadMapFromYaml(yamlLocation)
	if err != nil {
		log.Fatal(err)
	}

	os.Exit(m.Run())
}

func setupOptions(t *testing.T, dir string, prefix string) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  dir,
		Prefix:        prefix,
		ResourceGroup: resourceGroup,
		Region:        region,
		TerraformVars: map[string]interface{}{
			"access_tags": permanentResources["accessTags"],
		},
	})

	return options
}

func TestRunCompleteExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, completeExampleTerraformDir, "slz-vsi-com")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestRunCompleteUpgradeExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, completeExampleTerraformDir, "slz-vsi-com-upg")

	output, err := options.RunTestUpgrade()

	if !options.UpgradeTestSkipped {
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}
}

func setupFSCloudOptions(t *testing.T, prefix string) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  fsCloudExampleTerraformDir,
		Prefix:        prefix,
		ResourceGroup: resourceGroup,
		Region:        region,
		TerraformVars: map[string]interface{}{
			"skip_iam_authorization_policy": true, // The test account already has got a s2s policy setup that would clash
			"existing_kms_instance_guid":    permanentResources["hpcs_south"],
			"boot_volume_encryption_key":    permanentResources["hpcs_south_root_key_crn"],
			"access_tags":                   permanentResources["accessTags"],
		},
	})

	return options
}

func TestRunFSCloudExample(t *testing.T) {
	t.Parallel()

	options := setupFSCloudOptions(t, "slz-vsi-fscloud")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored.")
	assert.NotNil(t, output, "Expected some output")
}

func TestRunExistingSnapshotGroupExample(t *testing.T) {
	t.Parallel()

	// ***************************************************
	// NOTICE! MUST BE REPLACED!
	// These hardcoded values must be replaced with true snapshot
	// values once cloud resources are permanently replaced and
	// IDs can be entered into common-dev-assets files!
	// ***************************************************
	snapGroupId := "r014-0606d617-b866-4ae8-9588-84935b13ff55"

	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  snapshotExampleTerraformDir,
		Prefix:        "slz-vsi-snap",
		ResourceGroup: resourceGroup,
		Region:        "us-east", // hardcode due to image requirement
		TerraformVars: map[string]interface{}{
			"access_tags":                   permanentResources["accessTags"],
			"snapshot_consistency_group_id": snapGroupId,
		},
	})

	// Add a post-apply verfication
	options.PostApplyHook = verifyVolumeSnapshots

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored.")
	assert.NotNil(t, output, "Expected some output")

}

func verifyVolumeSnapshots(options *testhelper.TestOptions) error {

	if assert.Equal(options.Testing, "examples/snapshot", snapshotExampleTerraformDir) {
		options.Testing.Logf("DEBUG: value of global pr_test variable is: %s", snapshotExampleTerraformDir)
	}

	// ***************************************************
	// NOTICE! MUST BE REPLACED!
	// These hardcoded values must be replaced with true snapshot
	// values once cloud resources are permanently replaced and
	// IDs can be entered into common-dev-assets files!
	// ***************************************************
	snapBootId := "r014-5219de54-3f01-479f-9771-1d23afd13eb4"
	snapVol1Id := "r014-165d280e-d624-45bb-b463-6abd8878ae3f"
	snapVol2Id := "r014-baca1ccd-cc63-401a-a571-8427421b0d03"

	options.Testing.Log("====== START VERIFY OF SNAPSHOTS ========")

	// get ouput of last apply
	outputs, outputErr := terraform.OutputAllE(options.Testing, options.TerraformOptions)

	if assert.NoErrorf(options.Testing, outputErr, "error getting last terraform apply outputs: %s", outputErr) {
		// first, verify the outputs for snapshot IDs were correctly used from group
		assert.Equal(options.Testing, snapBootId, outputs["slz_vsi"].(map[string]interface{})["consistency_group_boot_snapshot_id"])
		// check to make sure that TWO attachment snapshots were configured from group
		if assert.Equal(options.Testing, 2, len(outputs["slz_vsi"].(map[string]interface{})["consistency_group_storage_snapshot_ids"].(map[string]interface{}))) {
			assert.Equal(options.Testing, snapVol1Id, outputs["slz_vsi"].(map[string]interface{})["consistency_group_storage_snapshot_ids"].(map[string]interface{})["vsi-block-1"].(string))
			assert.Equal(options.Testing, snapVol2Id, outputs["slz_vsi"].(map[string]interface{})["consistency_group_storage_snapshot_ids"].(map[string]interface{})["vsi-block-2"].(string))
		}
	}

	options.Testing.Log("====== END VERIFY OF SNAPSHOTS ========")

	return nil
}
