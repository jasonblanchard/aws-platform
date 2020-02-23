provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "tfplayground"
    key    = "terraform.tfstate"
    region = "eu-west-3"
  }
}
resource "aws_vpc" "playground_vpc" {
  assign_generated_ipv6_cidr_block = false
  cidr_block                       = "10.0.0.0/16"
  tags = {
    "Name" = "playground"
  }
}
resource "aws_subnet" "subnet" {
  assign_ipv6_address_on_creation = false
  cidr_block                      = "10.0.0.0/16"
  vpc_id                          = aws_vpc.playground_vpc.id
}

resource "aws_security_group" "playground_sg" {
  description = "custom VPC security group"
  egress = [
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    },
  ]
  ingress = [
    {
      cidr_blocks      = []
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = true
      to_port          = 0
    },
  ]
  name   = "playground"
  vpc_id = aws_vpc.playground_vpc.id
}

resource "aws_instance" "example" {
  ami                    = "ami-2757f631"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.playground_sg.id]
  # subnet_id = "subnet-0c62e7b2a1f32b68f"
  subnet_id = aws_subnet.subnet.id
}

resource "aws_s3_bucket" "playground_test_bucket" {
  bucket = "playground-test-bucket"
  acl    = "private"
}

resource "aws_iam_group" "bucket_writers" {
  name = "bucket-writers"
}

resource "aws_iam_group_membership" "bucket_writer_team" {
  name = "tf-testing-group-membership"

  users = [
    "jsonb"
  ]

  group = aws_iam_group.bucket_writers.name
}

resource "aws_iam_policy" "bucket_writer" {
  name        = "bucket-writer"
  path        = "/"
  description = "write to the test bucket"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "${aws_s3_bucket.playground_test_bucket.arn}/*"
    }
  ]
}
EOF
}

# resource "aws_iam_group_policy_attachment" "bucket-writer-attach" {
#   group      = aws_iam_group.bucket_writers.name
#   policy_arn = aws_iam_policy.bucket_writer.arn
# }
