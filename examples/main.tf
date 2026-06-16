# A small, provider-less Terraform configuration used to demonstrate TFLint.
#
# It is intentionally written to trip a rule from TFLint's bundled "terraform"
# ruleset, so running `tflint` against this directory produces output without
# needing `tflint --init` or any network access:
#
#   - `unused` is declared but never referenced -> terraform_unused_declarations
#
# See .tflint.hcl for the enabled rules.

terraform {
  required_version = ">= 1.0"
}

variable "name" {
  description = "Name to greet"
  type        = string
  default     = "world"
}

# Declared but never used - flagged by terraform_unused_declarations.
variable "unused" {
  description = "This variable is never referenced"
  type        = string
  default     = "orphan"
}

output "greeting" {
  value = "Hello, ${var.name}!"
}
