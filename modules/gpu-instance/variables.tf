variable "project_name"      { type = string }
variable "instance_type"     { type = string }
variable "use_spot"          { type = bool }
variable "key_pair_name"     { type = string }
variable "subnet_id"         { type = string }
variable "security_group_id" { type = string }
variable "volume_size_gb"    { type = number }