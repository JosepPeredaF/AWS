# S3
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "images" {
  bucket        = "${local.name}-images-${random_id.suffix.hex}"
  force_destroy = true # permite que terraform destroy borre objetos y versiones
}


resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket     = aws_s3_bucket.images.id
  depends_on = [aws_s3_bucket_versioning.images]

  rule {
    id     = "expirar-uploads"
    status = "Enabled"
    filter { prefix = "uploads/" }
    expiration { days = 30 }
    noncurrent_version_expiration { noncurrent_days = 1 }
  }

  rule {
    id     = "expirar-processed"
    status = "Enabled"
    filter { prefix = "processed/" }
    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 1 }
  }
}

# SQS 
resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name}-image-dlq"
  message_retention_seconds = 14 * 24 * 3600 # 14 días
}

resource "aws_sqs_queue" "main" {
  name                       = "${local.name}-image-queue"
  visibility_timeout_seconds = 360       # 6 veces el timeout de la lambda crop (60 s)
  message_retention_seconds  = 24 * 3600 # 1 día
  receive_wait_time_seconds  = 20        # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_s3_bucket.images.arn } }
    }]
  })
}

resource "aws_s3_bucket_notification" "uploads" {
  bucket     = aws_s3_bucket.images.id
  depends_on = [aws_sqs_queue_policy.allow_s3]

  queue {
    queue_arn     = aws_sqs_queue.main.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }
}