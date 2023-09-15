eksctl delete iamserviceaccount \
  --cluster ${EKS_CLUSTER_NAME} \
  --namespace kube-system \
  --name aws-load-balancer-controller
