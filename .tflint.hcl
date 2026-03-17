config {
  # Fail the run if any rules produce warnings — enforces clean pre-commit state
  force = false
}

plugin "aws" {
  enabled = true
  version = "0.38.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# ── Terraform core rules ──────────────────────────────────────────────────────

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

# ── AWS best-practice rules ───────────────────────────────────────────────────

rule "aws_instance_invalid_type" {
  enabled = true
}
