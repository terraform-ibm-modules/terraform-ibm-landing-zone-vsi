package test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

const defaultExampleTerraformDir = "examples/default"
const resourceGroup = "geretain-test-resources"
const region = "us-south"

// Remove this line after PR merge
// This is included to ignore changes to network-acls
var ignoreUpdates = []string{"module.slz_vpc.ibm_is_network_acl.network_acl[\"vpc-acl\"]"}

func setupOptions(t *testing.T, prefix string) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  defaultExampleTerraformDir,
		Prefix:        prefix,
		ResourceGroup: resourceGroup,
		Region:        region,
		IgnoreUpdates: testhelper.Exemptions{
			List: ignoreUpdates,
		},
		TerraformVars: map[string]interface{}{
			"create_security_group": true,
			"security_group": map[string]interface{}{
				"name":                         "test-lb-sg",
				"add_ibm_cloud_internal_rules": true,
				"rules": []map[string]interface{}{
					{
						"name":      "sgr-tcp",
						"direction": "inbound",
						"remote":    "0.0.0.0/0",
						"tcp": map[string]interface{}{
							"port_min": 8080,
							"port_max": 8080,
						},
					},
				},
			},
		},
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

func TestRunUpgradeBasicExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, "slz-vsi-upg")

	output, err := options.RunTestUpgrade()
	if !options.UpgradeTestSkipped {
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}
}
