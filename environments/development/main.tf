resource "aws_s3_bucket" "test_bucket" {
  bucket = "test-bucket-08162023-a"

  tags = {
    Environment = "development"
  }
}
