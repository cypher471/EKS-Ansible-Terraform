variable "region" {}
variable "name" {}
variable "cidr_block" {}
variable "azs" {
  type = list(string)
}
variable "node_subnets" {
  type = list(string)
}
variable "node_subnets_name" {
  type = list(string)
}
variable "pod_subnets" {
  type = list(string)
}
variable "pod_subnets_name" {
  type = list(string)
}
variable "security_group_name" {
  type = string
}
variable "eks_role_name" { 
  type = string
}
variable "eks_role_arn" { 
  type = string
}
variable "cluster_name" { 
  type = string
}
variable "eks_version" {
  type = string
}