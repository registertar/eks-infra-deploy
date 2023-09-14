$EKS_CLUSTER_NAME = $env:EKS_CLUSTER_NAME
$ACCOUNT_ID = $env:ACCOUNT_ID

eksctl delete iamserviceaccount `
  --cluster ${EKS_CLUSTER_NAME} `
  --namespace kube-system `
  --name aws-load-balancer-controller `
  --attach-policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy `
  --approve
