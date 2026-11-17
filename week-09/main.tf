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

resource "aws_ecs_cluster" "training" {   
  name = "training-cluster" 
} 

resource "aws_iam_role" "ecs_execution" {   
  name = "ecs-task-execution-role"   
  assume_role_policy = jsonencode({ 
    Version = "2012-10-17" 
    Statement = [{ 
      Action    = "sts:AssumeRole" 
      Effect    = "Allow" 
      Principal = { Service = "ecs-tasks.amazonaws.com" }     
    }]   
  }) 
} 

resource "aws_iam_role_policy_attachment" "ecs_execution" {   
  role       = aws_iam_role.ecs_execution.name 
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" 
} 

resource "aws_ecs_task_definition" "property_api" {   
  family                   = "property-api"   
  requires_compatibilities = ["FARGATE"]   
  network_mode             = "awsvpc"   
  cpu                      = "256"   
  memory                   = "512" 
  execution_role_arn       = aws_iam_role.ecs_execution.arn   
  container_definitions = jsonencode([{     
    name         = "property-api" 
    image        = "239124108981.dkr.ecr.us-west-1.amazonaws.com/property-api:latest"     
    essential    = true 
    portMappings = [{ containerPort = 8080, hostPort = 8080 }]   
  }]) 
} 

resource "aws_ecs_service" "property_api" {   
  name            = "property-api-service"   
  cluster         = aws_ecs_cluster.training.id 
  task_definition = aws_ecs_task_definition.property_api.arn   
  desired_count   = 1   
  launch_type     = "FARGATE" 

  network_configuration { 
    subnets          = module.vpc.public_subnets     
    assign_public_ip = true 
  } 
}