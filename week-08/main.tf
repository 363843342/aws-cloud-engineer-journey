provider "aws" { region = "us-west-1" } 

module "vpc" { 
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1" 

  name = "training-vpc-tf"
  cidr = "10.1.0.0/16" 

  azs             = ["us-west-1a", "us-west-1c"]
  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets = ["10.1.101.0/24", "10.1.102.0/24"] 

  enable_nat_gateway = true
  single_nat_gateway = true 
}