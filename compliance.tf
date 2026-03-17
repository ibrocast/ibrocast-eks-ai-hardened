# ── OIDC provider (enables IRSA — IAM Roles for Service Accounts) ─────────────

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = {
    Name = "${var.cluster_name}-oidc"
  }
}

# ── Terraform 1.5 check blocks (post-apply compliance assertions) ─────────────

# SEC-001: Verify KMS encryption is configured for the cluster
check "sec_001_kms_encryption_enabled" {
  assert {
    condition = length([
      for cfg in aws_eks_cluster.main.encryption_config :
      cfg if contains(cfg.resources, "secrets") && cfg.provider[0].key_arn != ""
    ]) > 0
    error_message = "SEC-001 FAILED: EKS cluster '${aws_eks_cluster.main.name}' must have KMS encryption enabled for secrets. Found no valid encryption_config block."
  }
}

# SEC-002: Verify the cluster API endpoint is private-only
check "sec_002_private_endpoint_only" {
  assert {
    condition     = aws_eks_cluster.main.vpc_config[0].endpoint_private_access == true && aws_eks_cluster.main.vpc_config[0].endpoint_public_access == false
    error_message = "SEC-002 FAILED: EKS cluster '${aws_eks_cluster.main.name}' must have endpoint_private_access=true and endpoint_public_access=false. Public internet exposure is not permitted in production."
  }
}
