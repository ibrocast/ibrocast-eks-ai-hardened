# ── KMS key for EKS secrets envelope encryption ───────────────────────────────

resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster ${var.cluster_name} envelope encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${var.cluster_name}-eks-kms"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}
