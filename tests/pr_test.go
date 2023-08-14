package test

import (
	"fmt"
	"log"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testschematic"
)

const defaultExampleTerraformDir = "examples/default"
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

func setupOptions(t *testing.T, prefix string) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  defaultExampleTerraformDir,
		Prefix:        prefix,
		ResourceGroup: resourceGroup,
		Region:        region,
		TerraformVars: map[string]interface{}{
			"access_tags": permanentResources["accessTags"],
		},
	})

	return options
}

func TestRunUpgradeBasicExample(t *testing.T) {
	t.Parallel()

	t.Skip("Skipping upgrade test until QuickStart pattern is merged to primary branch")

	options := setupOptions(t, "slz-vsi-upg")

	output, err := options.RunTestUpgrade()
	if !options.UpgradeTestSkipped {
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}
}

func TestRunFSCloudExample(t *testing.T) {
	t.Parallel()

	t.Skip("Skipping upgrade test until QuickStart pattern is merged to primary branch")

	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  fsCloudExampleTerraformDir,
		Prefix:        "slz-fs-vsi",
		ResourceGroup: resourceGroup,
		Region:        region,
		TerraformVars: map[string]interface{}{
			"existing_kms_instance_guid": permanentResources["hpcs_south"],
			"boot_volume_encryption_key": permanentResources["hpcs_south_root_key_crn"],
		},
	})

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestRunBasicExampleSchematics(t *testing.T) {
	t.Parallel()

	// set up a schematics test
	options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
		Testing:                t,
		TarIncludePatterns:     []string{"*.tf", fmt.Sprintf("%s/*.tf", defaultExampleTerraformDir)},
		TemplateFolder:         defaultExampleTerraformDir,
		Prefix:                 "slz-vsi-schematic",
		Tags:                   []string{"test-schematic"},
		DeleteWorkspaceOnFail:  false,
		WaitJobCompleteMinutes: 60,
	})

	options.TerraformVars = []testschematic.TestSchematicTerraformVar{
		{Name: "ibmcloud_api_key", Value: options.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
		{Name: "region", Value: region, DataType: "string"},
		{Name: "prefix", Value: options.Prefix, DataType: "string"},
	}

	// Idempotent test
	err := options.RunSchematicTest()
	assert.NoError(t, err, "Schematic Test had unexpected error")
}
