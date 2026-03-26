# Terraform / OpenTofu CLI Cheatsheet

Replace `terraform` with `tofu` for OpenTofu. Commands and flags are identical
unless noted otherwise.

---

## Initialization and Formatting

```bash
terraform init                         # Download providers, modules, configure backend
terraform init -upgrade                # Upgrade providers to latest matching constraints
terraform init -migrate-state          # Migrate state when changing backend config
terraform init -reconfigure            # Reinitialize backend without migrating state
terraform init -backend-config=KEY=VAL # Override backend config at init time

terraform fmt                          # Format .tf files in current directory
terraform fmt -check                   # CI: exit non-zero if files need formatting
terraform fmt -recursive               # Format all .tf files in subdirectories too
terraform fmt -diff                    # Show formatting diff without writing

terraform validate                     # Check syntax and internal consistency (no API calls)
```

## Planning

```bash
terraform plan                                   # Preview changes
terraform plan -out=plan.tfplan                   # Save plan for exact replay
terraform plan -var="instance_type=t3.large"      # Override a variable
terraform plan -var-file=staging.tfvars           # Use a specific variable file
terraform plan -target=module.vpc                 # Plan only a specific resource/module
terraform plan -replace="aws_instance.web"        # Force resource recreation in plan
terraform plan -refresh-only                      # Detect drift without making changes
terraform plan -generate-config-out=generated.tf  # Auto-generate config for import blocks
terraform plan -destroy                           # Preview what destroy would do
terraform plan -json                              # Machine-readable JSON output

terraform show plan.tfplan                        # Human-readable view of a saved plan
terraform show -json plan.tfplan                  # JSON view of a saved plan
```

## Applying

```bash
terraform apply                          # Apply with interactive approval
terraform apply plan.tfplan              # Apply a saved plan (no re-approval needed)
terraform apply -auto-approve            # Skip approval prompt (CI only)
terraform apply -replace="aws_instance.web"  # Force recreation during apply
terraform apply -target=aws_instance.web # Apply only a specific resource
terraform apply -parallelism=20          # Increase parallel operations (default 10)

terraform destroy                        # Destroy all managed resources
terraform destroy -target=aws_instance.web  # Destroy a specific resource
terraform destroy -auto-approve          # Skip approval (CI only)
```

## State Operations

```bash
terraform state list                           # List all resources in state
terraform state list module.vpc                # List resources in a module
terraform state show aws_instance.web          # Show attributes of one resource
terraform state mv aws_instance.a aws_instance.b  # Rename resource in state
terraform state mv 'module.old' 'module.new'   # Move between modules
terraform state rm aws_instance.web            # Remove from state (keeps real resource)
terraform state pull                           # Download remote state as JSON
terraform state push terraform.tfstate         # Upload local state (dangerous)
terraform state replace-provider hashicorp/aws registry.example.com/aws  # Swap provider

terraform force-unlock LOCK_ID                 # Release stuck state lock
```

## Workspace Management

```bash
terraform workspace list               # List all workspaces (* marks current)
terraform workspace show               # Print current workspace name
terraform workspace new staging         # Create and switch to new workspace
terraform workspace select production   # Switch to existing workspace
terraform workspace delete staging      # Delete workspace (must have empty state)
```

## Import and Migration

```bash
# CLI import (legacy, still works)
terraform import aws_instance.web i-1234567890abcdef0

# Config-driven import (1.5+): add import block to .tf, then:
terraform plan -generate-config-out=generated.tf   # Generate resource config
terraform apply                                    # Execute the import
```

## Outputs and Inspection

```bash
terraform output                        # Show all outputs
terraform output instance_ip            # Show single output value
terraform output -json                  # All outputs as JSON
terraform output -raw instance_ip       # Raw value (no quotes, for scripts)

terraform console                       # Interactive expression evaluator
terraform graph | dot -Tpng > graph.png # Generate dependency graph image
terraform providers                     # List required providers
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64  # Multi-platform lock
terraform version                       # Show Terraform and provider versions
```

## Debugging

```bash
# Enable verbose logging
export TF_LOG=TRACE                     # TRACE, DEBUG, INFO, WARN, ERROR
export TF_LOG_PATH=terraform.log        # Persist logs to file

# Separate core vs provider logs
export TF_LOG_CORE=TRACE
export TF_LOG_PROVIDER=DEBUG

# Inspect state
terraform state pull | jq .            # Pretty-print full state
terraform state pull | jq '.resources | length'  # Count managed resources
terraform state show -json aws_instance.web | jq .  # Single resource as JSON

# Disable logging
export TF_LOG=OFF
unset TF_LOG TF_LOG_PATH
```

## OpenTofu-Specific

```bash
# State encryption (OpenTofu 1.7+) -- configured in terraform block:
# terraform {
#   encryption {
#     key_provider "pbkdf2" "my_key" { passphrase = var.passphrase }
#     method "aes_gcm" "encrypt" { keys = key_provider.pbkdf2.my_key }
#     state { method = method.aes_gcm.encrypt }
#   }
# }

tofu init                               # Same commands, different binary
tofu plan
tofu apply
```
