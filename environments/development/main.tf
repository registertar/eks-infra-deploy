resource "aws_kms_key" "master_cmk" {
  description             = "Master KMS key"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "master_cmk" {
  name          = "alias/eks"
  target_key_id = aws_kms_key.master_cmk.key_id
}

output "MASTER_ARN" {
  value = aws_kms_alias.master_cmk.arn
}