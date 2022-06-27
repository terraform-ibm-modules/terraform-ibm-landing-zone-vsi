package test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

const defaultExampleTerraformDir = "examples/default"
const resourceGroup = "geretain-test-slz-vsi"

func setupOptions(t *testing.T, prefix string) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  defaultExampleTerraformDir,
		Prefix:        prefix,
		ResourceGroup: resourceGroup,
	})

	return options
}

func TestRunBasicExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, "slz-vsi")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

// TODO: Uncomment upgrade test after first release
//func TestRunUpgradeBasicExample(t *testing.T) {
//	t.Parallel()
//
//	options := setupOptions(t, "slz-vsi-upg")
//
//	output, err := options.RunTestUpgrade()
//	if !options.UpgradeTestSkipped {
//		assert.Nil(t, err, "This should not have errored")
//		assert.NotNil(t, output, "Expected some output")
//	}
//}
