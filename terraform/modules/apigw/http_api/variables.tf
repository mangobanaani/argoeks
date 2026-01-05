variable "name" {
  type = string
}
variable "stage_name" {
  type    = string
  default = "$default"
}
variable "cors_allowed_origins" {
  type    = list(string)
  default = ["*"]
}
variable "cors_allowed_methods" {
  type    = list(string)
  default = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
}
variable "cors_allowed_headers" {
  type    = list(string)
  default = ["*"]
}
variable "routes" {
  description = "List of routes with Lambda integrations"
  type        = list(object({ route_key = string, lambda_arn = string }))
}
variable "tags" {
  type    = map(string)
  default = {}
}
