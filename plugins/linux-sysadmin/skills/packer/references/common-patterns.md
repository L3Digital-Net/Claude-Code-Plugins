# Common Packer HCL2 Patterns

Working examples for everyday image-building patterns. All examples use HCL2
format (`.pkr.hcl` files).

---

## 1. QEMU/KVM Image from ISO

Build a qcow2 disk image from an ISO using KVM acceleration. Serve a
preseed/kickstart file via Packer's built-in HTTP server.

```hcl
packer {
  required_plugins {
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "iso_url" {
  type    = string
  default = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.9.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
}

source "qemu" "debian" {
  iso_url           = var.iso_url
  iso_checksum      = var.iso_checksum
  output_directory  = "output-debian"
  format            = "qcow2"
  accelerator       = "kvm"
  disk_size         = "20G"
  memory            = 2048
  cpus              = 2
  headless          = true
  http_directory    = "http"
  boot_wait         = "5s"
  boot_command      = [
    "<esc><wait>",
    "auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "debian-installer=en_US.UTF-8 locale=en_US.UTF-8 ",
    "kbd-chooser/method=us keyboard-configuration/xkb-keymap=us ",
    "netcfg/get_hostname=packer netcfg/get_domain=local ",
    "<enter>",
  ]
  ssh_username      = "root"
  ssh_password      = "packer"
  ssh_timeout       = "30m"
  shutdown_command   = "shutdown -P now"
  vm_name           = "debian-12-base.qcow2"
}

build {
  sources = ["source.qemu.debian"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y qemu-guest-agent cloud-init",
      "apt-get clean",
    ]
  }

  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "output-debian/SHA256SUMS"
  }
}
```

---

## 2. Docker Image with Tag and Push

Build a Docker image, tag it, and push to a registry. Uses the commit mode
with chained post-processors.

```hcl
packer {
  required_plugins {
    docker = {
      version = "~> 1"
      source  = "github.com/hashicorp/docker"
    }
  }
}

variable "registry" {
  type    = string
  default = "ghcr.io/myorg"
}

variable "app_version" {
  type    = string
  default = "1.0.0"
}

source "docker" "app" {
  image  = "python:3.12-slim"
  commit = true
  changes = [
    "EXPOSE 8000",
    "WORKDIR /opt/app",
    "CMD [\"python\", \"-m\", \"uvicorn\", \"main:app\", \"--host\", \"0.0.0.0\"]",
  ]
}

build {
  sources = ["source.docker.app"]

  provisioner "shell" {
    inline = [
      "pip install --no-cache-dir uvicorn fastapi",
    ]
  }

  provisioner "file" {
    source      = "src/"
    destination = "/opt/app/"
  }

  # Chained: tag then push (post-processors block = sequential pipeline)
  post-processors {
    post-processor "docker-tag" {
      repository = "${var.registry}/myapp"
      tags       = ["latest", var.app_version]
    }

    post-processor "docker-push" {}
  }
}
```

---

## 3. AWS AMI with Source AMI Filter

Build an AMI from the latest Ubuntu image. Uses `source_ami_filter` so the
template does not hardcode a specific AMI ID.

```hcl
packer {
  required_plugins {
    amazon = {
      version = "~> 1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_prefix" {
  type    = string
  default = "my-app"
}

locals {
  timestamp = formatdate("YYYYMMDD-HHmmss", timestamp())
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "${var.ami_prefix}-${local.timestamp}"
  instance_type = var.instance_type
  region        = var.region
  ssh_username  = "ubuntu"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]   # Canonical
    most_recent = true
  }

  tags = {
    Name        = "${var.ami_prefix}-${local.timestamp}"
    Environment = "production"
    Builder     = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y nginx",
      "sudo systemctl enable nginx",
    ]
  }

  provisioner "file" {
    source      = "config/nginx.conf"
    destination = "/tmp/nginx.conf"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf",
      "sudo nginx -t",
    ]
  }

  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }
}
```

---

## 4. Multi-Source Build

Define multiple sources in one template. The build block runs provisioners
against all sources in parallel.

```hcl
packer {
  required_plugins {
    amazon = {
      version = "~> 1"
      source  = "github.com/hashicorp/amazon"
    }
    docker = {
      version = "~> 1"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "amazon-ebs" "production" {
  ami_name      = "myapp-${formatdate("YYYYMMDD", timestamp())}"
  instance_type = "t3.micro"
  region        = "us-east-1"
  ssh_username  = "ubuntu"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]
    most_recent = true
  }
}

source "docker" "testing" {
  image  = "ubuntu:24.04"
  commit = true
}

build {
  sources = [
    "source.amazon-ebs.production",
    "source.docker.testing",
  ]

  # Runs on both sources
  provisioner "shell" {
    inline = [
      "apt-get update || sudo apt-get update",
      "apt-get install -y curl jq || sudo apt-get install -y curl jq",
    ]
  }

  # Only runs on the Docker source
  provisioner "shell" {
    only   = ["docker.testing"]
    inline = ["echo 'Docker-specific setup'"]
  }

  # Only runs on the AWS source
  provisioner "shell" {
    only   = ["amazon-ebs.production"]
    inline = ["sudo systemctl enable amazon-ssm-agent"]
  }
}
```

The `only` and `except` meta-parameters filter provisioners and post-processors
to specific sources.

---

## 5. Ansible Provisioner with Galaxy Roles

Use the `ansible` provisioner to run playbooks from the host machine over SSH.
Installs Galaxy roles/collections before running the playbook.

```hcl
packer {
  required_plugins {
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "base" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  output_directory = "output-ansible"
  format           = "qcow2"
  accelerator      = "kvm"
  disk_size        = "20G"
  headless         = true
  ssh_username     = "root"
  ssh_password     = "packer"
  ssh_timeout      = "30m"
  shutdown_command  = "shutdown -P now"
}

build {
  sources = ["source.qemu.base"]

  # Install Python first (required by Ansible)
  provisioner "shell" {
    inline = ["apt-get update && apt-get install -y python3"]
  }

  provisioner "ansible" {
    playbook_file   = "ansible/site.yml"
    galaxy_file     = "ansible/requirements.yml"
    extra_arguments = [
      "--extra-vars", "env=production packer_build=true",
      "--scp-extra-args", "'-O'",
    ]
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
    ]
  }
}
```

---

## 6. Variables, Locals, and Validation

Parameterize builds with input variables. Use locals for computed values and
validation blocks to catch misconfigurations early.

```hcl
variable "environment" {
  type        = string
  description = "Target environment"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "disk_size_gb" {
  type    = number
  default = 20

  validation {
    condition     = var.disk_size_gb >= 10 && var.disk_size_gb <= 500
    error_message = "Disk size must be between 10 and 500 GB."
  }
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

locals {
  disk_size = "${var.disk_size_gb}G"
  build_id  = "${var.environment}-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
  common_tags = {
    Environment = var.environment
    Builder     = "packer"
    BuildID     = local.build_id
  }
}
```

Set variables: `-var 'environment=production'`, `-var-file=prod.pkrvars.hcl`,
`PKR_VAR_environment=production`, or `*.auto.pkrvars.hcl` (auto-loaded).

---

## 7. Post-Processor Pipeline

Chain post-processors to transform artifacts in sequence. Each `post-processors`
(plural) block creates a pipeline where each step receives the prior artifact.

```hcl
build {
  sources = ["source.qemu.debian"]

  # Independent post-processors (each gets the original build artifact)
  post-processor "manifest" {
    output = "packer-manifest.json"
  }

  post-processor "checksum" {
    checksum_types = ["sha256", "md5"]
    output         = "output-debian/{{.BuildName}}_{{.ChecksumType}}.checksum"
  }

  # Sequenced pipeline: compress then upload
  post-processors {
    post-processor "compress" {
      output = "output-debian/{{.BuildName}}.tar.gz"
    }

    post-processor "shell-local" {
      inline = [
        "echo 'Uploading compressed artifact...'",
        "aws s3 cp output-debian/{{.BuildName}}.tar.gz s3://my-images-bucket/",
      ]
    }
  }
}
```

---

## 8. Data Source for AMI Lookup

Use a data source to query for an AMI at plan time rather than hardcoding IDs.
Data sources are HCL2-only.

```hcl
data "amazon-ami" "base" {
  filters = {
    name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  owners      = ["099720109477"]
  most_recent = true
  region      = "us-east-1"
}

source "amazon-ebs" "app" {
  ami_name      = "myapp-{{timestamp}}"
  instance_type = "t3.micro"
  region        = "us-east-1"
  source_ami    = data.amazon-ami.base.id
  ssh_username  = "ubuntu"
}
```

---

## 9. Conditional Provisioners with only/except

Target provisioners to specific sources or skip them conditionally.

```hcl
build {
  sources = [
    "source.amazon-ebs.ubuntu",
    "source.qemu.debian",
    "source.docker.testing",
  ]

  # Runs on all sources
  provisioner "shell" {
    inline = ["echo 'Build: ${source.type}.${source.name}'"]
  }

  # Skip Docker (doesn't need cloud-init)
  provisioner "shell" {
    except = ["docker.testing"]
    inline = ["sudo apt-get install -y cloud-init"]
  }

  # Only for AWS (install SSM agent)
  provisioner "shell" {
    only   = ["amazon-ebs.ubuntu"]
    inline = [
      "sudo snap install amazon-ssm-agent --classic",
      "sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service",
    ]
  }

  # Only for QEMU (install guest agent)
  provisioner "shell" {
    only   = ["qemu.debian"]
    inline = ["sudo apt-get install -y qemu-guest-agent"]
  }
}
```

---

## 10. CI/CD Build Script

Wrapper script for running Packer in CI. Sets logging, caching, and
non-interactive options.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Enable Packer logging to file
export PACKER_LOG=1
export PACKER_LOG_PATH="packer-build.log"

# Persistent cache directory (mount in CI for reuse)
export PACKER_CACHE_DIR="/var/cache/packer"

# Disable version checkpoint
export CHECKPOINT_DISABLE=1

# Disable color for log parsing
export PACKER_NO_COLOR=1

# Variables from CI environment
export PKR_VAR_environment="${ENVIRONMENT:-dev}"
export PKR_VAR_app_version="${CI_COMMIT_TAG:-dev}"

# Install plugins
packer init -upgrade .

# Validate before building
packer validate .

# Build with limited parallelism
packer build -parallel-builds=1 -on-error=cleanup .
```
