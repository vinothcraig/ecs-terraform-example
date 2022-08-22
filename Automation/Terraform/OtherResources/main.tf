### Provider declaration
provider "aws" {
 profile                              = var.aws_profile
 region                               = var.region_name
}

## ------------------------------------------------------------------------------------------------------------------------------------------------- ##

### Resource methods
### VPC & NAT GW
resource "aws_vpc" "vpc_01" {
  cidr_block                          = var.vpc_01_cidr
  enable_dns_hostnames                = true
  enable_dns_support                  =  true
    tags = {
    Name                              = var.vpc_01_name
  }
}
resource "aws_internet_gateway" "igw_01" {
  vpc_id                              = aws_vpc.vpc_01.id
    tags = {
    Name                              = var.igw_01_name
  }
}

## ------------------------------------------------------------------------------------------------------------------------------------------------- ##
### SUBNET

# public subnet #1 
resource "aws_subnet" "pub_sub_01" {
  cidr_block                          = var.pub_sub_01_cidr
  vpc_id                              = aws_vpc.vpc_01.id
  availability_zone                   = var.az1_name
  map_public_ip_on_launch             = "true"

  tags = {
    Name                              = var.pub_sub_01_name
    Visibility                        = "Public"
  }
}

# public subnet #2 
resource "aws_subnet" "pub_sub_02" {
  cidr_block                          = var.pub_sub_02_cidr
  vpc_id                              = aws_vpc.vpc_01.id
  availability_zone                   = var.az2_name
  map_public_ip_on_launch             = "true"

  tags = {
    Name                              = var.pub_sub_02_name
    Visibility                        = "Public"
  }
}

## ------------------------------------------------------------------------------------------------------------------------------------------------- ##

### PUB SUB - ROUTE TABLE ASSOCIATION

# allow internet access to nat #1
resource "aws_route_table" "pub_rt_01" {
  vpc_id                            = aws_vpc.vpc_01.id

  route {
    cidr_block                      = "0.0.0.0/0"
    gateway_id                      = aws_internet_gateway.igw_01.id
  }

  tags = {
    Name                            = var.pub_rt_01_name
  }
}
resource "aws_route_table_association" "internet_for_pub_01" {
  route_table_id                    = aws_route_table.pub_rt_01.id
  subnet_id                         = aws_subnet.pub_sub_01.id
}
resource "aws_route_table_association" "internet_for_pub_02" {
  route_table_id                    = aws_route_table.pub_rt_01.id
  subnet_id                         = aws_subnet.pub_sub_02.id
}

## ------------------------------------------------------------------------------------------------------------------------------------------------- ##

### SECURITY GROUP
resource "aws_security_group" "common_sg_01" {
  name                              = var.sg_01_name
  description                       = "Ingress to only openVPN and Infra Subnets"
  vpc_id                            = aws_vpc.vpc_01.id

  # outbound internet access
  egress {
    from_port                       = 0
    to_port                         = 0
    protocol                        = "-1"
    cidr_blocks                     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "allow_inbound_traffic_1" {
  type                              = "ingress"
  from_port                         = 443
  to_port                           = 443
  protocol                          = "all"
  cidr_blocks                       = [var.infra_cidr_01]
  security_group_id                 = aws_security_group.common_sg_01.id
}


resource "aws_security_group_rule" "allow_inbound_traffic_2" {
  type                              = "ingress"
  from_port                         = 443
  to_port                           = 443
  protocol                          = "all"
  cidr_blocks                       = [var.vpc_01_cidr]
  security_group_id                 = aws_security_group.common_sg_01.id
}

## ------------------------------------------------------------------------------------------------------------------------------------------------- ##

## ALB

resource "aws_lb_target_group" "my-target-group" {
  health_check {
    interval            = 300
    path                = "/"
    protocol            = "HTTP"
    timeout             = 120
    healthy_threshold   = 10
    unhealthy_threshold = 10
  }

  name        =  var.alb_tg_name
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc_01.id
}

resource "aws_lb" "my-aws-alb" {
  name     = var.alb_name
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.common_sg_01.id]
  subnets = [aws_subnet.pub_sub_01.id, aws_subnet.pub_sub_02.id]
  enable_deletion_protection = false
  tags = {
    Name = var.alb_name
  }
  ip_address_type    = "ipv4"
}

resource "aws_lb_listener" "my-test-alb-listner" {
  load_balancer_arn = aws_lb.my-aws-alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_arn


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my-target-group.arn
  }
}

## ------------------------------------------------------------------------------------------------------------------------------------------------- ##

## ECS CLUSTER

resource "aws_ecs_cluster" "my_cluster" {
  name = var.ecs_cluster_name # Naming the cluster
}


## ECS TASK

resource "aws_ecs_task_definition" "my_first_task" {
  family                   = "api-task" # Naming our first task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "api-task",
      "image": "662343139402.dkr.ecr.us-east-1.amazonaws.com/api-ecr-repo:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "hostPort": 8000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = var.ecs_memory        # Specifying the memory our container requires
  cpu                      = var.ecs_cpu        # Specifying the CPU our container requires
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

## ------------------------------------------------------------------------------------------------------------------------------------------------- ##

## ECS SERVICE
resource "aws_ecs_service" "my_first_service" {
  name            =  var.ecs_service_name                           # Naming our first service
  cluster         = "${aws_ecs_cluster.my_cluster.id}"             # Referencing our created Cluster
  task_definition = "${aws_ecs_task_definition.my_first_task.arn}" # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 1 # Setting the number of containers we want deployed to 1

  network_configuration {
    subnets          = ["${aws_subnet.pub_sub_01.id}"]
    security_groups  = [aws_security_group.common_sg_01.id] 
    assign_public_ip = true # Providing our containers with public IPs
  }
  
  load_balancer {
   target_group_arn = aws_lb_target_group.my-target-group.arn
   container_name   = var.container_name
   container_port   = var.container_port
 }
}

## ------------------------------------------------------------------------------------------------------------------------------------------------- ##

## ROUTE 53

resource "aws_route53_record" "hostname" {
  zone_id = var.hosted_zone_id
  name    = var.host_name
  type    = "A"

  alias {
    name                   = "${aws_lb.my-aws-alb.dns_name}"
    zone_id                = "${aws_lb.my-aws-alb.zone_id}"
    evaluate_target_health = true
  }
}

## ------------------------------------------------------------------------------------------------------------------------------------------------- ##

### Variable Declaration
variable "aws_profile" {}
variable "vpc_01_name" {}
variable "vpc_01_cidr" {}
variable "igw_01_name" {}
variable "pub_sub_01_cidr" {}
variable "pub_sub_01_name" {}

variable "pub_sub_02_cidr" {}
variable "pub_sub_02_name" {}
variable "pub_rt_01_name" {}
variable "sg_01_name" {}
variable "infra_cidr_01" {}
variable "region_name" {}
variable "az1_name" {}
variable "az2_name" {}


variable "ecs_cluster_name" {}
variable "ecs_service_name" {}
variable "ecs_memory" {}
variable "ecs_cpu" {}

variable "alb_tg_name" {}
variable "alb_name" {}
variable "cert_arn" {}
variable "container_port" {}
variable "container_name" {}
variable "hosted_zone_id" {}
variable "host_name" {}


## ------------------------------------------------------------------------------------------------------------------------------------------------- ##

# ### Outpus
# output "vpc_01_id" {
#     value                           = aws_vpc.vpc_01.id
# }
# output "pub_sub_01_id" {
#     value                           = aws_subnet.pub_sub_01.id
# }
# output "sg_01_name" {
#     value                           = aws_security_group.common_sg_01.id
# }