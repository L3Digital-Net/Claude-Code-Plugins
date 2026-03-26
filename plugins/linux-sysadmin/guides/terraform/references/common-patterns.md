# Common Terraform / OpenTofu HCL Patterns

Working examples for everyday infrastructure patterns. All examples use AWS
for consistency, but the HCL patterns apply to any provider.

---

## 1. Basic Provider + Resource

Minimal configuration that creates a single resource.

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "assets" {
  bucket = "my-app-assets-20240101"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

---

## 2. Variables and Outputs

Parameterize config with input variables; export computed values as outputs.

```hcl
# variables.tf
variable "environment" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "Number of instances to create"

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database password (pass via TF_VAR_db_password or .tfvars)"
}

# outputs.tf
output "bucket_arn" {
  value       = aws_s3_bucket.assets.arn
  description = "ARN of the assets bucket"
}

output "instance_ips" {
  value       = aws_instance.app[*].public_ip
  description = "Public IPs of all app instances"
}
```

---

## 3. Remote State Backend (S3 with Locking)

S3 backend with DynamoDB locking (traditional) or native S3 locking (TF 1.10+).

```hcl
# Traditional: DynamoDB for state locking
terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state"
    key            = "prod/network/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"        # table with LockID as partition key
  }
}

# Modern (Terraform 1.10+): native S3 locking without DynamoDB
terraform {
  backend "s3" {
    bucket       = "mycompany-terraform-state"
    key          = "prod/network/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true                       # S3-native lock file
  }
}
```

**Bootstrap the state bucket** (chicken-and-egg: create the bucket manually or
with a separate config using local state, then migrate):
```bash
aws s3api create-bucket --bucket mycompany-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket mycompany-terraform-state \
  --versioning-configuration Status=Enabled
```

---

## 4. Module Usage (Local and Registry)

### Local module
```hcl
# modules/vpc/main.tf defines the module's resources.
# Root module invokes it:
module "vpc" {
  source = "./modules/vpc"

  cidr_block  = "10.0.0.0/16"
  environment = var.environment
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
```

### Registry module
```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"                         # pin to major version

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}
```

### Git module
```hcl
module "custom" {
  source = "git::https://github.com/org/terraform-modules.git//network?ref=v2.1.0"
}
```

---

## 5. for_each with Maps

Create named resources from a map. Each resource is keyed by the map key,
making additions/removals safe (unlike count, which shifts indices).

```hcl
variable "buckets" {
  type = map(object({
    versioning = bool
    acl        = string
  }))
  default = {
    logs   = { versioning = true,  acl = "log-delivery-write" }
    assets = { versioning = false, acl = "private" }
    backup = { versioning = true,  acl = "private" }
  }
}

resource "aws_s3_bucket" "this" {
  for_each = var.buckets
  bucket   = "${var.project}-${each.key}"

  tags = {
    Name = each.key
  }
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = { for k, v in var.buckets : k => v if v.versioning }
  bucket   = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}
```

---

## 6. Dynamic Blocks

Generate repeated nested blocks from a collection. Use sparingly; literal
blocks are easier to read when the list is short.

```hcl
variable "ingress_rules" {
  type = list(object({
    port        = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    { port = 80,  protocol = "tcp", cidr_blocks = ["0.0.0.0/0"],    description = "HTTP" },
    { port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"],    description = "HTTPS" },
    { port = 22,  protocol = "tcp", cidr_blocks = ["10.0.0.0/8"],   description = "SSH internal" },
  ]
}

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web server security group"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## 7. Data Source Usage

Read existing infrastructure or external data without creating resources.

```hcl
# Look up the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]   # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Look up an existing VPC by tags
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["main-vpc"]
  }
}

# Reference in a resource
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = data.aws_vpc.main.id

  tags = {
    Name = "web-server"
  }
}
```

---

## 8. Conditional Creation with count

Create a resource only when a boolean variable is true. The `count = X ? 1 : 0`
pattern produces zero or one instances.

```hcl
variable "create_monitoring" {
  type    = bool
  default = true
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.create_monitoring ? 1 : 0

  alarm_name          = "high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = aws_instance.web.id
  }
}

# Reference a conditional resource (may not exist):
output "alarm_arn" {
  value = var.create_monitoring ? aws_cloudwatch_metric_alarm.cpu[0].arn : null
}
```

---

## 9. Moved Blocks for Refactoring

Rename resources or restructure modules without destroying infrastructure.
Terraform updates state automatically on the next apply.

```hcl
# Renamed a resource
moved {
  from = aws_instance.server
  to   = aws_instance.web
}

# Moved a resource into a module
moved {
  from = aws_s3_bucket.logs
  to   = module.logging.aws_s3_bucket.logs
}

# Switched from count to for_each
moved {
  from = aws_instance.app[0]
  to   = aws_instance.app["web"]
}
```

After applying, the moved blocks can be removed from config (they are
one-time migration directives).

---

## 10. Import Blocks (Terraform 1.5+ / OpenTofu 1.5+)

Declarative import brings existing resources under Terraform management.

```hcl
# Step 1: declare the import
import {
  to = aws_instance.legacy_server
  id = "i-0abc123def456789a"
}

# Step 2: generate the resource config automatically
#   terraform plan -generate-config-out=generated.tf

# Step 3: review generated.tf, adjust as needed, then apply
#   terraform apply

# The import block can be removed after the resource is in state.
```

### Bulk import with for_each (OpenTofu 1.7+)
```hcl
variable "existing_buckets" {
  type    = map(string)
  default = {
    logs   = "my-logs-bucket"
    assets = "my-assets-bucket"
  }
}

import {
  for_each = var.existing_buckets
  to       = aws_s3_bucket.imported[each.key]
  id       = each.value
}
```

---

## 11. Lifecycle Rules

Control resource behavior beyond the default create/update/delete.

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  lifecycle {
    # Create the replacement before destroying the old one (minimize downtime)
    create_before_destroy = true

    # Never destroy this resource via Terraform (protect critical infra)
    prevent_destroy = true

    # Ignore external changes to tags (e.g., auto-tagging by AWS Config)
    ignore_changes = [tags["LastScannedAt"]]

    # Recreate this instance when the AMI data source finds a newer image
    replace_triggered_by = [data.aws_ami.ubuntu.id]
  }
}
```
