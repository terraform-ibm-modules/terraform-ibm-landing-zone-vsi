package test

import (
	"fmt"
	"log"
	"os"
	"strings"
	"testing"

	"github.com/IBM/go-sdk-core/core"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/cloudinfo"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testaddons"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testschematic"
)

const basicExampleTerraformDir = "examples/basic"
const completeExampleTerraformDir = "examples/complete"
const fsCloudExampleTerraformDir = "examples/fscloud"

// calls vsi module twice on same subnets to check for duplicate names
const multiModuleOneVpcTerraformDir = "examples/multi-profile-one-vpc"

const snapshotExampleTerraformDir = "examples/snapshot"
const fullyConfigFlavorDir = "solutions/fully-configurable"

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
	// need to ignore because of a provider issue: https://github.com/IBM-Cloud/terraform-provider-ibm/issues/5527
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
			"boot_volume_encryption_key":    permanentResources["hpcs_south_root_key_crn"],
			"access_tags":                   permanentResources["accessTags"],
		},
	})
	// need to ignore because of a provider issue: https://github.com/IBM-Cloud/terraform-provider-ibm/issues/5527
	options.IgnoreUpdates = testhelper.Exemptions{
		List: []string{
			fmt.Sprintf("module.slz_vsi.module.fscloud_vsi.ibm_is_volume.volume[\"%s-vpc-subnet-a-0-%s\"]", options.Prefix, options.Prefix),
			fmt.Sprintf("module.slz_vsi.module.fscloud_vsi.ibm_is_volume.volume[\"%s-vpc-subnet-b-0-%s\"]", options.Prefix, options.Prefix),
			fmt.Sprintf("module.slz_vsi.module.fscloud_vsi.ibm_is_volume.volume[\"%s-vpc-subnet-c-0-%s\"]", options.Prefix, options.Prefix),
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

func TestRunExistingSnapshotGroupExample(t *testing.T) {
	t.Parallel()

	snapGroupId := permanentResources["snapshot_group_au_syd_group_id"]

	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  snapshotExampleTerraformDir,
		Prefix:        "slz-vsi-snap",
		ResourceGroup: resourceGroup,
		Region:        "au-syd", // hardcode due to image requirement
		TerraformVars: map[string]interface{}{
			"access_tags":                   permanentResources["accessTags"],
			"snapshot_consistency_group_id": snapGroupId,
			"image_id":                      "r026-979eb199-efe0-4bb6-baf9-8b3f9a6e8f52", // for au-syd region
		},
	})

	// Add a post-apply verification
	options.PostApplyHook = verifyVolumeSnapshots

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored.")
	assert.NotNil(t, output, "Expected some output")

}

func verifyVolumeSnapshots(options *testhelper.TestOptions) error {

	if assert.Equal(options.Testing, "examples/snapshot", snapshotExampleTerraformDir) {
		options.Testing.Logf("DEBUG: value of global pr_test variable is: %s", snapshotExampleTerraformDir)
	}

	snapBootId := permanentResources["snapshot_group_au_syd_boot_id"]
	snapVol1Id := permanentResources["snapshot_group_au_syd_vol1_id"]
	snapVol2Id := permanentResources["snapshot_group_au_syd_vol2_id"]

	options.Testing.Log("====== START VERIFY OF SNAPSHOTS ========")

	// get output of last apply
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

func sshPublicKey(t *testing.T) string {
	pubKey, keyErr := common.GenerateSshRsaPublicKey()

	// if error producing key (very unexpected) fail test immediately
	require.NoError(t, keyErr, "SSH Keygen failed, without public ssh key test cannot continue")

	return pubKey
}

func provisionPreReq(t *testing.T) (string, *terraform.Options, error) {
	// ------------------------------------------------------------------------------------
	// Provision existing resources first
	// ------------------------------------------------------------------------------------
	prefix := fmt.Sprintf("vpc-%s", strings.ToLower(random.UniqueId()))
	realTerraformDir := "./existing-resources"
	tempTerraformDir, _ := files.CopyTerraformFolderToTemp(realTerraformDir, fmt.Sprintf(prefix+"-%s", strings.ToLower(random.UniqueId())))
	tags := common.GetTagsFromTravis()

	// Verify ibmcloud_api_key variable is set
	checkVariable := "TF_VAR_ibmcloud_api_key"
	val, present := os.LookupEnv(checkVariable)
	require.True(t, present, checkVariable+" environment variable not set")
	require.NotEqual(t, "", val, checkVariable+" environment variable is empty")
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
		// assert.True(t, existErr == nil, "Init and Apply of temp existing resource failed")
		return "", nil, existErr
	}
	return prefix, existingTerraformOptions, nil
}

// Test the fully-configurable DA with defaults
func TestFullyConfigurable(t *testing.T) {
	t.Parallel()

	prefix, existingTerraformOptions, existErr := provisionPreReq(t)

	if existErr != nil {
		assert.True(t, existErr == nil, "Init and Apply of temp existing resource failed")
	} else {
		// ------------------------------------------------------------------------------------
		// Deploy DA
		// ------------------------------------------------------------------------------------
		options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
			Testing: t,
			Region:  region,
			Prefix:  prefix,
			TarIncludePatterns: []string{
				"*.tf",
				"modules/*/*.tf",
				fullyConfigFlavorDir + "/*.tf",
			},
			TemplateFolder:         fullyConfigFlavorDir,
			Tags:                   []string{"vsi-da-test"},
			DeleteWorkspaceOnFail:  false,
			WaitJobCompleteMinutes: 60,
		})

		options.TerraformVars = []testschematic.TestSchematicTerraformVar{
			{Name: "ibmcloud_api_key", Value: options.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
			{Name: "existing_resource_group_name", Value: terraform.Output(t, existingTerraformOptions, "resource_group_name"), DataType: "string"},
			{Name: "vsi_resource_tags", Value: options.Tags, DataType: "list(string)"},
			{Name: "vsi_access_tags", Value: permanentResources["accessTags"], DataType: "list(string)"},
			{Name: "prefix", Value: terraform.Output(t, existingTerraformOptions, "prefix"), DataType: "string"},
			{Name: "existing_vpc_crn", Value: terraform.Output(t, existingTerraformOptions, "vpc_crn"), DataType: "string"},
			{Name: "existing_subnet_id", Value: terraform.Output(t, existingTerraformOptions, "subnet_id"), DataType: "string"},
			{Name: "image_id", Value: terraform.Output(t, existingTerraformOptions, "image_id"), DataType: "string"},
			{Name: "existing_secrets_manager_instance_crn", Value: permanentResources["secretsManagerCRN"], DataType: "string"},
		}
		err := options.RunSchematicTest()
		assert.Nil(t, err, "This should not have errored")
	}

	// Check if "DO_NOT_DESTROY_ON_FAILURE" is set
	envVal, _ := os.LookupEnv("DO_NOT_DESTROY_ON_FAILURE")
	// Destroy the temporary existing resources if required
	if t.Failed() && strings.ToLower(envVal) == "true" {
		fmt.Println("Terratest failed. Debug the test and delete resources manually.")
	} else {
		logger.Log(t, "START: Destroy (prereq resources)")
		terraform.Destroy(t, existingTerraformOptions)
		terraform.WorkspaceDelete(t, existingTerraformOptions, prefix)
		logger.Log(t, "END: Destroy (prereq resources)")
	}
}

// Test the fully-configurable DA using existing KMS key
func TestExistingKeyFullyConfigurable(t *testing.T) {
	t.Parallel()

	sshPublicKey := sshPublicKey(t)

	prefix, existingTerraformOptions, existErr := provisionPreReq(t)

	if existErr != nil {
		assert.True(t, existErr == nil, "Init and Apply of temp existing resource failed")
	} else {
		// ------------------------------------------------------------------------------------
		// Deploy DA
		// ------------------------------------------------------------------------------------
		options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
			Testing: t,
			Region:  region,
			Prefix:  prefix,
			TarIncludePatterns: []string{
				"*.tf",
				"modules/*/*.tf",
				fullyConfigFlavorDir + "/*.tf",
			},
			TemplateFolder:         fullyConfigFlavorDir,
			Tags:                   []string{"vsi-da-test"},
			DeleteWorkspaceOnFail:  false,
			WaitJobCompleteMinutes: 60,
		})

		options.TerraformVars = []testschematic.TestSchematicTerraformVar{
			{Name: "ibmcloud_api_key", Value: options.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
			{Name: "existing_resource_group_name", Value: terraform.Output(t, existingTerraformOptions, "resource_group_name"), DataType: "string"},
			{Name: "vsi_resource_tags", Value: options.Tags, DataType: "list(string)"},
			{Name: "vsi_access_tags", Value: permanentResources["accessTags"], DataType: "list(string)"},
			{Name: "prefix", Value: terraform.Output(t, existingTerraformOptions, "prefix"), DataType: "string"},
			{Name: "existing_vpc_crn", Value: terraform.Output(t, existingTerraformOptions, "vpc_crn"), DataType: "string"},
			{Name: "existing_subnet_id", Value: terraform.Output(t, existingTerraformOptions, "subnet_id"), DataType: "string"},
			{Name: "image_id", Value: terraform.Output(t, existingTerraformOptions, "image_id"), DataType: "string"},
			{Name: "existing_boot_volume_kms_key_crn", Value: permanentResources["hpcs_south_root_key_crn"], DataType: "string"},
			{Name: "kms_encryption_enabled_boot_volume", Value: true, DataType: "bool"},
			{Name: "auto_generate_ssh_key", Value: false, DataType: "bool"},
			{Name: "ssh_public_keys", Value: []string{sshPublicKey}, DataType: "list(string)"},
		}
		err := options.RunSchematicTest()
		assert.Nil(t, err, "This should not have errored")
	}

	// Check if "DO_NOT_DESTROY_ON_FAILURE" is set
	envVal, _ := os.LookupEnv("DO_NOT_DESTROY_ON_FAILURE")
	// Destroy the temporary existing resources if required
	if t.Failed() && strings.ToLower(envVal) == "true" {
		fmt.Println("Terratest failed. Debug the test and delete resources manually.")
	} else {
		logger.Log(t, "START: Destroy (prereq resources)")
		terraform.Destroy(t, existingTerraformOptions)
		terraform.WorkspaceDelete(t, existingTerraformOptions, prefix)
		logger.Log(t, "END: Destroy (prereq resources)")
	}
}

// Run upgrade test on fully-configurable variation
func TestUpgradeFullyConfigurable(t *testing.T) {
	t.Parallel()

	prefix, existingTerraformOptions, existErr := provisionPreReq(t)

	if existErr != nil {
		assert.True(t, existErr == nil, "Init and Apply of temp existing resource failed")
	} else {
		// ------------------------------------------------------------------------------------
		// Deploy DA
		// ------------------------------------------------------------------------------------
		options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
			Testing: t,
			Region:  region,
			Prefix:  prefix,
			TarIncludePatterns: []string{
				"*.tf",
				"modules/*/*.tf",
				fullyConfigFlavorDir + "/*.tf",
			},
			TemplateFolder:         fullyConfigFlavorDir,
			Tags:                   []string{"vsi-da-test"},
			DeleteWorkspaceOnFail:  false,
			WaitJobCompleteMinutes: 60,
		})

		options.TerraformVars = []testschematic.TestSchematicTerraformVar{
			{Name: "ibmcloud_api_key", Value: options.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
			{Name: "existing_resource_group_name", Value: terraform.Output(t, existingTerraformOptions, "resource_group_name"), DataType: "string"},
			{Name: "vsi_resource_tags", Value: options.Tags, DataType: "list(string)"},
			{Name: "vsi_access_tags", Value: permanentResources["accessTags"], DataType: "list(string)"},
			{Name: "prefix", Value: terraform.Output(t, existingTerraformOptions, "prefix"), DataType: "string"},
			{Name: "existing_vpc_crn", Value: terraform.Output(t, existingTerraformOptions, "vpc_crn"), DataType: "string"},
			{Name: "existing_subnet_id", Value: terraform.Output(t, existingTerraformOptions, "subnet_id"), DataType: "string"},
			{Name: "image_id", Value: terraform.Output(t, existingTerraformOptions, "image_id"), DataType: "string"},
			{Name: "existing_secrets_manager_instance_crn", Value: permanentResources["secretsManagerCRN"], DataType: "string"},
			{Name: "kms_encryption_enabled_boot_volume", Value: true, DataType: "bool"},
			{Name: "existing_kms_instance_crn", Value: permanentResources["hpcs_south_crn"], DataType: "string"},
		}
		err := options.RunSchematicUpgradeTest()
		assert.Nil(t, err, "This should not have errored")
	}

	// Check if "DO_NOT_DESTROY_ON_FAILURE" is set
	envVal, _ := os.LookupEnv("DO_NOT_DESTROY_ON_FAILURE")
	// Destroy the temporary existing resources if required
	if t.Failed() && strings.ToLower(envVal) == "true" {
		fmt.Println("Terratest failed. Debug the test and delete resources manually.")
	} else {
		logger.Log(t, "START: Destroy (prereq resources)")
		terraform.Destroy(t, existingTerraformOptions)
		terraform.WorkspaceDelete(t, existingTerraformOptions, prefix)
		logger.Log(t, "END: Destroy (prereq resources)")
	}
}

// This test will include TWO calls to the VSI module on the same VPC and subnets.
// To plug a test gap where we found that the module prefix was not used to name some resources
// and if deployed to same subnets would have duplicate names.
func TestRunMultiProfileExample(t *testing.T) {
	t.Parallel()

	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  multiModuleOneVpcTerraformDir,
		Prefix:        "slz-vsi-mp",
		ResourceGroup: resourceGroup,
		Region:        region,
		TerraformVars: map[string]interface{}{
			"access_tags": permanentResources["accessTags"],
		},
	})

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestDefaultConfiguration(t *testing.T) {
	t.Parallel()

	options := testaddons.TestAddonsOptionsDefault(&testaddons.TestAddonOptions{
		Testing:       t,
		Prefix:        "vsideft",
		ResourceGroup: resourceGroup,
		QuietMode:     true, // Suppress logs except on failure
	})

	options.AddonConfig = cloudinfo.NewAddonConfigTerraform(
		options.Prefix,
		"deploy-arch-ibm-vsi-vpc",
		"fully-configurable",
		map[string]interface{}{
			"prefix":                       options.Prefix,
			"existing_resource_group_name": resourceGroup,
			"region":                       "eu-de",
			"secrets_manager_service_plan": "trial",
			"image_id":                     "r010-17a6c2b3-c93b-4018-87ca-f078ef21e02b", // image_id for ibm-ubuntu-24-04-3-minimal-amd64-1 in eu-de
		},
	)

	/*
		Event notifications is manually disabled in this test because event notifications DA creates kms keys and during undeploy the order of key protect and event notifications
		is not considered by projects as EN is not a direct dependency of VSI DA. So undeploy fails, because
		key protect instance can't be deleted because of active keys created by EN. Hence for now, we don't want to deploy
		EN.

		Issue has been created for projects team. https://github.ibm.com/epx/projects/issues/4750
		Once that is fixed, we can remove the logic to disable SM
	*/
	options.AddonConfig.Dependencies = []cloudinfo.AddonConfig{
		{
			OfferingName:   "deploy-arch-ibm-event-notifications",
			OfferingFlavor: "fully-configurable",
			Enabled:        core.BoolPtr(false), // explicitly disabled
		},
	}

	err := options.RunAddonTest()
	require.NoError(t, err)
}

// TestDependencyPermutations runs dependency permutations for VSI and all its dependencies
func TestDependencyPermutations(t *testing.T) {

	t.Skip("Skipping dependency permutations")
	t.Parallel()

	options := testaddons.TestAddonsOptionsDefault(&testaddons.TestAddonOptions{
		Testing: t,
		Prefix:  "vsi-perm",
		AddonConfig: cloudinfo.AddonConfig{
			OfferingName:   "deploy-arch-ibm-vsi-vpc",
			OfferingFlavor: "fully-configurable",
			Inputs: map[string]interface{}{
				"prefix":                                "es-perm",
				"region":                                "eu-de",
				"existing_resource_group_name":          resourceGroup,
				"image_id":                              "r010-17a6c2b3-c93b-4018-87ca-f078ef21e02b", // image_id for ibm-ubuntu-24-04-3-minimal-amd64-1 in eu-de
				"secrets_manager_service_plan":          "trial",
				"existing_secrets_manager_instance_crn": permanentResources["secretsManagerCRN"],
			},
		},
	})

	err := options.RunAddonPermutationTest()
	assert.NoError(t, err, "Dependency permutation test should not fail")
}
