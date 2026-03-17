# unit_test.tftest.hcl — Terraform native tests (terraform test, v1.7+)
# Uses mock providers so no AWS credentials are required.
#
# All runs use command = apply (not plan) because the SEC-001/SEC-002 check
# blocks in compliance.tf reference computed attributes on aws_eks_cluster
# (encryption_config[*].provider[0].key_arn, vpc_config[0].endpoint_*) that
# are only "known after apply". Mock apply populates them from the mock_resource
# defaults below, allowing check blocks to evaluate successfully.

# ── Mock providers ────────────────────────────────────────────────────────────

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      id    = "us-east-1"
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "AIDAMOCKUSERID"
    }
  }

  # Seed the EKS cluster with values that satisfy the SEC-001/SEC-002 checks.
  mock_resource "aws_eks_cluster" {
    defaults = {
      endpoint = "https://mock.eks.us-east-1.amazonaws.com"
      encryption_config = [
        {
          provider  = [{ key_arn = "arn:aws:kms:us-east-1:123456789012:key/mock-key-id" }]
          resources = ["secrets"]
        }
      ]
      vpc_config = [
        {
          endpoint_private_access   = true
          endpoint_public_access    = false
          subnet_ids                = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
          cluster_security_group_id = "sg-mock"
        }
      ]
      identity = [
        { oidc = [{ issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/MOCKID" }] }
      ]
    }
  }
}

mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = {
      certificates = [{ sha1_fingerprint = "aabbccddeeff00112233445566778899aabbccdd" }]
    }
  }
}

# ── Test: default variable values are sane ────────────────────────────────────

run "default_variable_values_are_sane" {
  command = apply

  variables {
    cost_center = "cc-test-001"
  }

  assert {
    condition     = var.vpc_cidr == "10.0.0.0/16"
    error_message = "Default vpc_cidr must be '10.0.0.0/16', got '${var.vpc_cidr}'."
  }

  assert {
    condition     = var.k8s_version == "1.29"
    error_message = "Default k8s_version must be '1.29', got '${var.k8s_version}'."
  }

  assert {
    condition     = var.min_size <= var.desired_size && var.desired_size <= var.max_size
    error_message = "Scaling config must satisfy min_size (${var.min_size}) <= desired_size (${var.desired_size}) <= max_size (${var.max_size})."
  }

  assert {
    condition     = var.environment == "production"
    error_message = "Default environment must be 'production', got '${var.environment}'."
  }
}

# ── Test: overridden values propagate correctly ───────────────────────────────

run "overridden_vpc_cidr_and_k8s_version_propagate" {
  command = apply

  variables {
    vpc_cidr    = "172.16.0.0/16"
    k8s_version = "1.30"
    environment = "staging"
    cost_center = "cc-test-002"
  }

  assert {
    condition     = var.vpc_cidr == "172.16.0.0/16"
    error_message = "Overridden vpc_cidr should be '172.16.0.0/16', got '${var.vpc_cidr}'."
  }

  assert {
    condition     = var.k8s_version == "1.30"
    error_message = "Overridden k8s_version should be '1.30', got '${var.k8s_version}'."
  }

  assert {
    condition     = var.environment == "staging"
    error_message = "Overridden environment should be 'staging', got '${var.environment}'."
  }
}

# ── Test: EKS cluster name matches the variable ───────────────────────────────

run "eks_cluster_name_matches_variable" {
  command = apply

  variables {
    cluster_name = "my-test-cluster"
    cost_center  = "cc-test-003"
  }

  assert {
    condition     = aws_eks_cluster.main.name == var.cluster_name
    error_message = "aws_eks_cluster.main.name must equal var.cluster_name ('${var.cluster_name}')."
  }
}

# ── Test: private subnets use correct CIDR offsets ────────────────────────────

run "private_subnets_use_correct_cidr_blocks" {
  command = apply

  variables {
    cost_center = "cc-test-004"
  }

  assert {
    condition     = aws_subnet.private[0].cidr_block == cidrsubnet(var.vpc_cidr, 4, 0)
    error_message = "Private subnet[0] CIDR mismatch: expected '${cidrsubnet(var.vpc_cidr, 4, 0)}', got '${aws_subnet.private[0].cidr_block}'."
  }

  assert {
    condition     = aws_subnet.public[0].cidr_block == cidrsubnet(var.vpc_cidr, 4, 3)
    error_message = "Public subnet[0] CIDR mismatch: expected '${cidrsubnet(var.vpc_cidr, 4, 3)}', got '${aws_subnet.public[0].cidr_block}'."
  }
}
