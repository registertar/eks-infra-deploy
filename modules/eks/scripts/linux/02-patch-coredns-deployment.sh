kubectl patch deployment coredns -n kube-system --type json -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]' || true
# https://antonputra.com/amazon/create-aws-eks-fargate-using-terraform/#update-coredns-to-run-on-aws-fargate
# https://docs.aws.amazon.com/eks/latest/userguide/fargate-getting-started.html
