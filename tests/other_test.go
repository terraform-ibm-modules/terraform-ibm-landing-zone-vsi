// Tests in this file are NOT run in the PR pipeline. They are run in the continuous testing pipeline along with the ones in pr_test.go
package test

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRunBasicExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, basicExampleTerraformDir, "slz-vsi-basic")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}
