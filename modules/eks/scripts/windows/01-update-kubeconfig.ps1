$EKS_CLUSTER_NAME = $env:EKS_CLUSTER_NAME

aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME}
