output "MASTER_ARN" {
  value = aws_kms_alias.master_cmk.arn
}

output "eks_cluster_endpoint" {
  value = module.EKS.eks_cluster_endpoint
}

output "eks_cluster_name" {
  value = module.EKS.eks_cluster_name
}

output "kubeconfig_certificate_authority_data" {
  value = module.EKS.kubeconfig_certificate_authority_data
}
