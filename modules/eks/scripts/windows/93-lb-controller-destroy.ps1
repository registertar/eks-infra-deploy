$EKS_CLUSTER_NAME = $env:EKS_CLUSTER_NAME

eksctl delete iamserviceaccount `
  --cluster ${EKS_CLUSTER_NAME} `
  --namespace kube-system `
  --name aws-load-balancer-controller
