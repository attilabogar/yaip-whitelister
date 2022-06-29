variable "bucket_src" {
  type        = string
  description = "edge-door upload bucket"
}

variable "bucket_dst" {
  type        = string
  description = "edge-door polling bucket"
}

variable "aws_region" {
  type        = string
  description = "AWS region of edge-door"
}

variable "aws_profile" {
  type        = string
  description = "AWS profile for provisioning"
}

variable "users" {
  type        = list(string)
  description = "edge-door users"
}
