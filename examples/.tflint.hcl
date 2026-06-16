# Minimal TFLint configuration for the example.
#
# Only the bundled "terraform" ruleset is used here, so `tflint` runs fully
# offline against this directory - no `tflint --init` required.
#
# Real-world rulesets for AWS, Google Cloud, Azure, etc. are external plugins.
# To use them, add a `plugin` block with a `source`/`version` and run
# `tflint --init` first (this needs network access and a writable
# ~/.tflint.d/plugins directory - see the README).

rule "terraform_unused_declarations" {
  enabled = true
}
