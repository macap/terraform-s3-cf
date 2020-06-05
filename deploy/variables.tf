variable "project_name" {
  type    = string
  default = "tf-awsify"
}

variable "domain" {
  type    = string
  default = "awsify.ml"

}

variable "public_dir" {
  type    = string
  default = "www"
}

variable "logs_bucket" {
  type    = string
  default = "depx-logs"

}

variable "tags" {
  type = object({
    Name        = string
    Environment = string
  })
  default = {
    Name        = "TF-awsify"
    Environment = "Dev"
  }
}