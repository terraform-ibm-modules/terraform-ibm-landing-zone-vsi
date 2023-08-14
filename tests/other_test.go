// Tests in this file are NOT run in the PR pipeline. They are run in the continuous testing pipeline along with the ones in pr_test.go
package test

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRunBasicExample(t *testing.T) {
	t.Parallel()

	t.Skip("Skipping upgrade test until QuickStart pattern is merged to primary branch")

	options := setupOptions(t, "slz-vsi")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}
