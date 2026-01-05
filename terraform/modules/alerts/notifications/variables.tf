variable "name_prefix" {
  type = string
}
variable "emails" {
  type    = list(string)
  default = []
}
variable "slack_workspace_id" {
  type    = string
  default = ""
}
variable "slack_channel_id" {
  type    = string
  default = ""
}
