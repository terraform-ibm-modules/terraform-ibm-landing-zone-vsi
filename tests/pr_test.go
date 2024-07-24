package test

import (
	"fmt"
	"log"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

const basicExampleTerraformDir = "examples/basic"
const completeExampleTerraformDir = "examples/complete"
const fsCloudExampleTerraformDir = "examples/fscloud"

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
	options.IgnoreUpdates = testhelper.Exemptions{
		List: []string{
			fmt.Sprintf("module.slz_vsi.ibm_is_volume.volume[\"%s-vpc-subnet-a-0-%s\"]", options.Prefix, options.Prefix),
			fmt.Sprintf("module.slz_vsi.ibm_is_volume.volume[\"%s-vpc-subnet-b-0-%s\"]", options.Prefix, options.Prefix),
			fmt.Sprintf("module.slz_vsi.ibm_is_volume.volume[\"%s-vpc-subnet-c-0-%s\"]", options.Prefix, options.Prefix),
		},
	}

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
	options.IgnoreUpdates = testhelper.Exemptions{
		List: []string{
			fmt.Sprintf("module.slz_vsi.module.fscloud_vsi.ibm_is_volume.volume[\"%s-vpc-subnet-a-0-%s\"]", options.Prefix, options.Prefix),
			fmt.Sprintf("module.slz_vsi.module.fscloud_vsi.ibm_is_volume.volume[\"%s-vpc-subnet-b-0-%s\"]", options.Prefix, options.Prefix),
			fmt.Sprintf("module.slz_vsi.module.fscloud_vsi.ibm_is_volume.volume[\"%s-vpc-subnet-c-0-%s\"]", options.Prefix, options.Prefix),
			// "module.slz_vsi.module.fscloud_vsi.ibm_is_volume.volume[\"" + options.Prefix + "-vpc-subnet-a-0-" + options.Prefix + "\"]",
		},
	}
	return options
}

func TestRunFSCloudExample(t *testing.T) {
	t.Parallel()

	options := setupFSCloudOptions(t, "slz-vsi-fscloud")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored.")
	assert.NotNil(t, output, "Expected some output")
}
