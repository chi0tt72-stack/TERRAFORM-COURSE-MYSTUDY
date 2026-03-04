resource "aws_s3_bucket" "main" {
  bucket = "${var.bucket_prefix}-${var.environment}-${var.random_suffix}"

  tags = merge(var.tags, {
    Name = "${var.bucket_prefix}-${var.environment}"
  })
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets  = true
}
