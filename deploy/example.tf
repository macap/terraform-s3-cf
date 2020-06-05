# use: 
#$ export AWS_ACCESS_KEY_ID="anaccesskey"
#$ export AWS_SECRET_ACCESS_KEY="asecretkey"
#$ export AWS_DEFAULT_REGION="us-west-2"

provider "aws" {}

provider "aws" {
  alias  = "us-east"
  region = "us-east-1"
}

// 1. Create S3 bucket in eu-central-1
resource "aws_s3_bucket" "bucket" {
  bucket = var.project_name
  acl    = "private"

  tags = var.tags
}

// 3. Request SSL certificate
data "aws_route53_zone" "main" {
  name         = var.domain
  private_zone = false
}

resource "aws_acm_certificate" "cert" {
  domain_name               = var.domain
  subject_alternative_names = ["www.${var.domain}"]
  validation_method         = "DNS"

  provider = aws.us-east
}

resource "aws_route53_record" "cert_validation" {
  name     = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type     = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id  = "${data.aws_route53_zone.main.zone_id}"
  records  = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl      = 60
  provider = aws.us-east
}

resource "aws_route53_record" "cert_validation_alt1" {
  name     = "${aws_acm_certificate.cert.domain_validation_options.1.resource_record_name}"
  type     = "${aws_acm_certificate.cert.domain_validation_options.1.resource_record_type}"
  zone_id  = "${data.aws_route53_zone.main.zone_id}"
  records  = ["${aws_acm_certificate.cert.domain_validation_options.1.resource_record_value}"]
  ttl      = 60
  provider = aws.us-east
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn = "${aws_acm_certificate.cert.arn}"

  validation_record_fqdns = [
    "${aws_route53_record.cert_validation.fqdn}",
    "${aws_route53_record.cert_validation_alt1.fqdn}",
  ]
  provider = aws.us-east
}


// 4. Create cloudfront distribution
// 6. Handle errors in CF

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
}

resource "aws_cloudfront_distribution" "cf" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = "${aws_s3_bucket.bucket.bucket}/${var.public_dir}"
    origin_path = "/${var.public_dir}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "${var.logs_bucket}.s3.amazonaws.com"
    prefix          = "${var.project_name}_logs"
  }

  aliases = [var.domain, "www.${var.domain}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.bucket.bucket}/${var.public_dir}"

    compress = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  // USA, Canada, EU, Israel:
  price_class = "PriceClass_100"

  // no restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  // SPA routing: 
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  // SSL certificate:
  viewer_certificate {
    # cloudfront_default_certificate = true
    # acm_certificate_arn = var.cert_arn
    acm_certificate_arn = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method  = "sni-only"
  }
  tags = var.tags
}

// 4.1 Update S3 Bucket policy to allow CF access
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
    effect    = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
}

resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

// 2. Create hosted zone in Route53 
// 5. Alter hosted zones to point to CF

resource "aws_route53_record" "root_domainv4" {
  zone_id = "${data.aws_route53_zone.main.zone_id}"
  name    = "${var.domain}"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.cf.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.cf.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "root_domainv6" {
  zone_id = "${data.aws_route53_zone.main.zone_id}"
  name    = "${var.domain}"
  type    = "AAAA"

  alias {
    name                   = "${aws_cloudfront_distribution.cf.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.cf.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_domainv4" {
  zone_id = "${data.aws_route53_zone.main.zone_id}"
  name    = "www.${var.domain}"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.cf.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.cf.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_domainv6" {
  zone_id = "${data.aws_route53_zone.main.zone_id}"
  name    = "www.${var.domain}"
  type    = "AAAA"

  alias {
    name                   = "${aws_cloudfront_distribution.cf.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.cf.hosted_zone_id}"
    evaluate_target_health = false
  }
}

// output variables

output "cdn_domain" {
  value       = aws_cloudfront_distribution.cf.domain_name
  description = "Domain of CF distribution"
}

