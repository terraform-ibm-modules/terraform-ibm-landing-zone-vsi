// Tests in this file are NOT run in the PR pipeline. They are run in the continuous testing pipeline along with the ones in pr_test.go
package test

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRunBasicExample(t *testing.T) {
	t.Parallel()

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

	options := setupOptions(t, catalogImageExampleTerraformDir, "slz-vsi-cat")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestRunGen2BootExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, gen2bootExampleTerraformDir, "slz-vsi-gen2")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}
