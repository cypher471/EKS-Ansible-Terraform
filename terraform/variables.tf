variable "azs" {
  type = list(string)
}
variable "cidr_block" {}
variable "cluster_name" { 
  type = string
}
variable "ec2_endpoint" {
  type = string
}
variable "eks_endpoint" {
  type = string
}
variable "eks_role_arn" { 
  type = string
}
variable "eks_role_name" { 
  type = string
}
variable "eks_version" {
  type = string
}
variable "name" {}
variable "node_subnets" {
  type = list(string)
}
variable "node_subnets_name" {
  type = list(string)
}
variable "region" {}
variable "pod_subnets" {
  type = list(string)
}
variable "pod_subnets_name" {
  type = list(string)
}
variable "security_group_name" {
  type = string
}
variable "sts_endpoint" {
  type = string
}