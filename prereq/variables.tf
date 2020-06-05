variable "domain" {
    type = string
}

variable "tags" {
    type = object({
        Name = string
        Environment = string
    })
    default = {
        Name        = "TF-awsify"
        Environment = "Dev"
    }
}