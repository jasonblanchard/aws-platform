provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "tfplayground"
    key    = "ecs/terraform.tfstate"
    region = "eu-west-3"
  }
}

resource "aws_security_group" "lb_sg" {
  description = "controls access to the application ELB"

  vpc_id = "vpc-008da0625cb4025d8"
  name   = "tf-ecs-lbsg"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_alb" "app" {
  name            = "tf-example-alb-ecs"
  subnets         = ["subnet-024e3207afb8d1a5c", "subnet-0d44e27b1150a6830"]
  security_groups = [aws_security_group.lb_sg.id]
}

resource "aws_alb_target_group" "test" {
  name     = "tf-example-ecs-app"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-008da0625cb4025d8"
  target_type = "ip"

  health_check {
    interval = 10
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.app.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.test.id
    type             = "forward"
  }
}

resource "aws_iam_role" "ecs_service" {
  name = "tf_example_ecs_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "ecs" {
  # name = "tf-ecs-group/ecs-agent"
  name = "/ecs/app"
}

resource "aws_ecs_cluster" "foo" {
  name = "example-from-tf"

  setting {
    name = "containerInsights"
    value = "disabled"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "myEcsTaskExecutionRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "ecs_execution_policy" {
  name       = "myEcsTaskExecutionAttachment"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "template_file" "task_definition" {
  template = "${file("${path.module}/task-definition.json")}"

  vars = {
    log_group_name   = "${aws_cloudwatch_log_group.ecs.name}"
  }
}


resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  container_definitions    = data.template_file.task_definition.rendered
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "0.25 vCPU"
  memory                   = "0.5GB"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

}

resource "aws_ecs_service" "app" {
  name            = "app"
  cluster         = aws_ecs_cluster.foo.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = ["subnet-024e3207afb8d1a5c"]
    security_groups = ["sg-00f8b47417ace3e81"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.test.arn
    container_name   = "app"
    container_port   = 80
  }
}
