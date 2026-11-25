# INTENTIONALLY INSECURE - demo file to prove the pipeline blocks bad code.
# Never merge this branch.
resource "aws_s3_bucket" "insecure_demo" {
  bucket = "insecure-demo-bucket"
}

resource "aws_s3_bucket_acl" "insecure_demo" {
  bucket = aws_s3_bucket.insecure_demo.id
  acl    = "public-read"
}