terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    encrypt = true
    bucket = "mothersect-tf-state"
    dynamodb_table = "mothersect-tf-state-lock"
    key    = "daiya"
    region = "us-east-1"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Can possibly be replaced with the template module.
# https://registry.terraform.io/modules/hashicorp/dir/template/latest
locals {
  s3_origin_id = var.domain_url
}

resource "aws_s3_bucket" "daiya" {
  bucket = var.domain_url
}

# Enable public access for the S3 bucket
resource "aws_s3_bucket_public_access_block" "daiya" {
  bucket = aws_s3_bucket.daiya.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Apply public read policy to the bucket
resource "aws_s3_bucket_policy" "daiya_public_read" {
  bucket = aws_s3_bucket.daiya.id
  policy = data.aws_iam_policy_document.daiya_public_read.json

  depends_on = [aws_s3_bucket_public_access_block.daiya]
}

data "aws_iam_policy_document" "daiya_public_read" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.daiya.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_ownership_controls" "daiya" {
  bucket = aws_s3_bucket.daiya.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_website_configuration" "daiya" {
  bucket = aws_s3_bucket.daiya.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_route53_record" "daiya" {
  zone_id = var.zone_id
  name    = "${var.domain_url}."
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.daiya.domain_name
    zone_id                = aws_cloudfront_distribution.daiya.hosted_zone_id
    evaluate_target_health = false
  }
}

# Zombo-daiya
resource "aws_s3_object" "daiya_index" {
  content_type = "text/html"
  bucket       = aws_s3_bucket.daiya.id
  key          = "index.html"
  source       = "../src/index.html"
  etag        = filemd5("../src/index.html")
}

resource "aws_s3_object" "daiya_image" {
  content_type = "image/png"
  bucket       = aws_s3_bucket.daiya.id
  key          = "daiya_smile.png"
  source       = "../src/daiya_smile.png"
  etag        = filemd5("../src/daiya_smile.png")
}
