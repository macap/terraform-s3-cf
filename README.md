# Single Page Application infrastryctre on AWS

Terraform files to spin up infrastructure for Single Page Application (Frontend) on AWS.
It will:
- Create Route 53 Hosted Zone for your domain
- Create S3 bucket to keep website files
- Issue and validate (using DNS validation) SSL certificate using ACM
- Create CloudFront distribution 
- Add DNS records to your domain Hosted Zone pointing to CloudFront distribution

## Usage

Project contains two directories - **prereq** and **deploy**. Each of those serves different purpose:

### 1. Prereq - add domain to Route53

You need to create Route 53 Hosted Zone for your domain before creating actual infrastructure (as there is DNS validation for SSL certificate used). You can skip this step if you already have your domiain in Route 53.

```
$ cd prereq
$ terraform init
$ terraform apply
    # type in your domain name (without www.)
```
In output you will get nameservers which you have to set at your domain provider.

#### Additional config
In `prereq/variables.tf` you can set tags for Hosted Zone.

### 2. Deploy - create actual infrastructure

After your domain has Hosted Zone within Route 53, update variables in `deploy/variables.tf`:

- `project_name`: Globally unique project name to be set as a bucket name
- `domain`: Your domain (without www.)
- `public_dir`: Directory within your bucket with website files
- `logs_bucket`: Bucket to keep logs (you must create it by yourself, or use existing one)
- `tags`: Tags will be added to every resource created

Then:
```
$ cd deploy
$ terraform init
$ terraform apply
```

wait a few minutes and your infra will be ready :) 