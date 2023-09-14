package test

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"

	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

const basicExampleTerraformDir = "examples/basic"
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

func setupFSCloudOptions(t *testing.T, prefix string) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  fsCloudExampleTerraformDir,
		Prefix:        prefix,
		ResourceGroup: resourceGroup,
		Region:        region,
		TerraformVars: map[string]interface{}{
			"existing_kms_instance_guid": permanentResources["hpcs_south"],
			"boot_volume_encryption_key": permanentResources["hpcs_south_root_key_crn"],
			"access_tags":                permanentResources["accessTags"],
		},
	})

	return options
}

func TestRunUpgradeFSCloudExample(t *testing.T) {
	// t.Parallel()

	options := setupFSCloudOptions(t, "slz-vsi-upg")

	output, err := options.RunTestUpgrade()
	if !options.UpgradeTestSkipped {
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}
}

func TestRunFSCloudExample(t *testing.T) {
	// t.Parallel()

	options := setupFSCloudOptions(t, "slz-vsi-fscloud")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestRunSLZExample(t *testing.T) {
	t.Parallel()

	// // TODO: This test needs to be skipped until https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4722 is resolved
	// t.Skip("Skipping TestRunSLZExample due to a known provider issue with destroy")

	// ------------------------------------------------------------------------------------
	// Deploy SLZ VPC first since it is needed for the landing-zone extension input
	// ------------------------------------------------------------------------------------

	prefix := fmt.Sprintf("vsi-slz-%s", strings.ToLower(random.UniqueId()))
	realTerraformDir := "./resources"
	tempTerraformDir, _ := files.CopyTerraformFolderToTemp(realTerraformDir, fmt.Sprintf(prefix+"-%s", strings.ToLower(random.UniqueId())))
	tags := common.GetTagsFromTravis()

	// Verify ibmcloud_api_key variable is set
	checkVariable := "TF_VAR_ibmcloud_api_key"
	val, present := os.LookupEnv(checkVariable)
	require.True(t, present, checkVariable+" environment variable not set")
	require.NotEqual(t, "", val, checkVariable+" environment variable is empty")

	// Programmatically determine region to use based on availability
	region, _ := testhelper.GetBestVpcRegion(val, "../common-dev-assets/common-go-assets/cloudinfo-region-vpc-gen2-prefs.yaml", "eu-de")

	logger.Log(t, "Tempdir: ", tempTerraformDir)
	existingTerraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: tempTerraformDir,
		Vars: map[string]interface{}{
			"prefix":        prefix,
			"region":        region,
			"resource_tags": tags,
		},
		// Set Upgrade to true to ensure latest version of providers and modules are used by terratest.
		// This is the same as setting the -upgrade=true flag with terraform.
		Upgrade: true,
	})

	terraform.WorkspaceSelectOrNew(t, existingTerraformOptions, prefix)
	_, existErr := terraform.InitAndApplyE(t, existingTerraformOptions)
	if existErr != nil {
		assert.True(t, existErr == nil, "Init and Apply of temp existing resource failed")
	} else {
		outputJson := terraform.OutputJson(t, existingTerraformOptions, "vpc_data")
		var managementVpcID string
		var vpcs []struct {
			VpcID   string `json:"vpc_id"`
			VpcName string `json:"vpc_name"`
		}
		// Unmarshal the JSON data into the struct
		if err := json.Unmarshal([]byte(outputJson), &vpcs); err != nil {
			fmt.Println(err)
			return
		}
		// Loop through the vpcs and find the vpc_id when vpc_name is "<prefix>-management-vpc"
		for _, vpc := range vpcs {
			if vpc.VpcName == fmt.Sprintf("%s-management-vpc", prefix) {
				managementVpcID = vpc.VpcID
			}
		}
		// ------------------------------------------------------------------------------------
		// Deploy landing-zone extension
		// ------------------------------------------------------------------------------------
		options := testhelper.TestOptionsDefault(&testhelper.TestOptions{
			Testing:      t,
			TerraformDir: "extension/landing-zone",
			// Do not hard fail the test if the implicit destroy steps fail to allow a full destroy of resource to occur
			ImplicitRequired: false,
			TerraformVars: map[string]interface{}{
				"prefix":                     prefix,
				"region":                     region,
				"resource_group":             fmt.Sprintf("%s-management-rg", prefix),
				"existing_kms_instance_guid": permanentResources["hpcs_south"],
				"boot_volume_encryption_key": permanentResources["hpcs_south_root_key_crn"],
				"vpc_id":                     managementVpcID,
			},
		})

		output, err := options.RunTestConsistency()
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}

	// Check if "DO_NOT_DESTROY_ON_FAILURE" is set
	envVal, _ := os.LookupEnv("DO_NOT_DESTROY_ON_FAILURE")
	// Destroy the temporary existing resources if required
	if t.Failed() && strings.ToLower(envVal) == "true" {
		fmt.Println("Terratest failed. Debug the test and delete resources manually.")
	} else {
		logger.Log(t, "START: Destroy (existing resources)")
		terraform.Destroy(t, existingTerraformOptions)
		terraform.WorkspaceDelete(t, existingTerraformOptions, prefix)
		logger.Log(t, "END: Destroy (existing resources)")
	}
}
