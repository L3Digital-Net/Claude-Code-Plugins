# Common Cloud CLI Patterns

Practical patterns for authentication, storage, compute, and output filtering
across AWS CLI, Azure CLI, and Google Cloud CLI.

---

## 1. SSO / Federated Login

### AWS — IAM Identity Center (SSO)

Configure once, then re-authenticate with a single command:

```bash
# Configure SSO profile (interactive wizard)
aws configure sso

# ~/.aws/config after setup:
# [sso-session my-sso]
# sso_region = us-east-1
# sso_start_url = https://my-portal.awsapps.com/start
# sso_registration_scopes = sso:account:access
#
# [profile dev]
# sso_session = my-sso
# sso_account_id = 123456789012
# sso_role_name = PowerUserAccess
# region = us-west-2
# output = json

# Login (opens browser)
aws sso login --profile dev

# Use the profile
aws s3 ls --profile dev

# Or set it globally for the session
export AWS_PROFILE=dev
aws s3 ls
```

Multiple profiles can share the same `sso-session`, so you authenticate once
and access all accounts.

### Azure — Interactive Browser Login

```bash
# Standard interactive login (opens browser)
az login

# Select a subscription after login
az account set --subscription "My Subscription Name"

# View all available subscriptions
az account list --output table
```

Starting September 2025, Microsoft requires MFA for all user identities via
Azure CLI. Service principals and managed identities are exempt.

### GCloud — User Login with Configurations

```bash
# Initial setup (project, region, account)
gcloud init

# Or login separately
gcloud auth login

# Create a named configuration for a different project/account
gcloud config configurations create staging
gcloud config set project my-staging-project
gcloud config set compute/region us-east1
gcloud config set account user@example.com

# Switch between configurations
gcloud config configurations activate default
gcloud config configurations activate staging

# Override for a single command
gcloud compute instances list --project=other-project --configuration=staging
```

---

## 2. Service Account / Service Principal Auth

### AWS — IAM User Keys + Assume Role

```bash
# Store static credentials in a named profile
aws configure --profile automation
# Enter Access Key ID and Secret Access Key

# Better: assume a role with limited permissions
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/DeployRole \
  --role-session-name deploy-session \
  --duration-seconds 3600

# Parse and export the temporary credentials
eval $(aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/DeployRole \
  --role-session-name deploy-session \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text | \
  awk '{print "export AWS_ACCESS_KEY_ID="$1" AWS_SECRET_ACCESS_KEY="$2" AWS_SESSION_TOKEN="$3}')

# Verify
aws sts get-caller-identity
```

### Azure — Service Principal with Secret or Certificate

```bash
# Create a service principal with a client secret
az ad sp create-for-rbac --name "deploy-sp" \
  --role Contributor \
  --scopes /subscriptions/SUB_ID

# Returns: appId, password, tenant -- save these securely

# Login with the service principal
az login --service-principal \
  --username APP_ID \
  --password CLIENT_SECRET \
  --tenant TENANT_ID

# Login with certificate (PEM file containing both PRIVATE KEY and CERTIFICATE)
az login --service-principal \
  --username APP_ID \
  --certificate /path/to/cert.pem \
  --tenant TENANT_ID

# For managed identity (on Azure VMs, AKS, App Service, etc.)
az login --identity
# With a specific user-assigned managed identity:
az login --identity --username MANAGED_IDENTITY_CLIENT_ID
```

### GCloud — Service Account Key File

```bash
# Create a service account
gcloud iam service-accounts create deploy-sa \
  --display-name="Deploy Service Account"

# Grant permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:deploy-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

# Create a key file (use sparingly -- prefer workload identity)
gcloud iam service-accounts keys create sa-key.json \
  --iam-account=deploy-sa@PROJECT_ID.iam.gserviceaccount.com

# Activate the service account
gcloud auth activate-service-account \
  --key-file=sa-key.json

# For Application Default Credentials (used by client libraries)
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa-key.json

# Or use impersonation (no key file needed -- preferred)
gcloud auth application-default login \
  --impersonate-service-account=deploy-sa@PROJECT_ID.iam.gserviceaccount.com
```

---

## 3. Storage Upload/Download

### AWS — S3

```bash
# Upload a single file
aws s3 cp backup.tar.gz s3://my-bucket/backups/

# Upload with storage class
aws s3 cp large-archive.tar.gz s3://my-bucket/archives/ --storage-class GLACIER

# Download a file
aws s3 cp s3://my-bucket/backups/backup.tar.gz ./

# Sync a local directory to S3 (only uploads changed files)
aws s3 sync /var/backups/ s3://my-bucket/server-backups/ --delete

# Sync with exclusions
aws s3 sync . s3://my-bucket/code/ --exclude "*.log" --exclude ".git/*"

# Recursive copy
aws s3 cp s3://my-bucket/logs/ ./logs/ --recursive

# Generate a presigned URL (shareable, time-limited)
aws s3 presign s3://my-bucket/report.pdf --expires-in 86400
```

### Azure — Blob Storage

```bash
# Upload a single file
az storage blob upload \
  --account-name myaccount \
  --container-name backups \
  --file backup.tar.gz \
  --name backups/backup.tar.gz

# Upload an entire directory
az storage blob upload-batch \
  --account-name myaccount \
  --destination mycontainer \
  --source ./local-dir

# Download a file
az storage blob download \
  --account-name myaccount \
  --container-name backups \
  --name backups/backup.tar.gz \
  --file ./backup.tar.gz

# Sync a directory
az storage blob sync \
  --container mycontainer \
  --account-name myaccount \
  --source ./local-dir

# Generate SAS token for a blob
az storage blob generate-sas \
  --account-name myaccount \
  --container-name mycontainer \
  --name report.pdf \
  --permissions r \
  --expiry 2026-04-01T00:00:00Z \
  --https-only
```

### GCloud — Cloud Storage (GCS)

```bash
# Upload a single file (gcloud storage replaces gsutil)
gcloud storage cp backup.tar.gz gs://my-bucket/backups/

# Download a file
gcloud storage cp gs://my-bucket/backups/backup.tar.gz ./

# Sync a local directory to GCS
gcloud storage rsync /var/backups/ gs://my-bucket/server-backups/ --delete-unmatched-destination-objects

# Recursive copy with exclusions
gcloud storage cp -r ./code/ gs://my-bucket/code/ --exclude="*.log"

# Set storage class on upload
gcloud storage cp archive.tar.gz gs://my-bucket/archives/ --storage-class=NEARLINE

# Legacy gsutil (still works but deprecated)
gsutil cp file.txt gs://my-bucket/
gsutil -m rsync -r /local/dir gs://my-bucket/dir/
```

---

## 4. Instance Management

### AWS — EC2

```bash
# List all instances with useful fields
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# List only running instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --output table

# Start/stop/reboot
aws ec2 start-instances --instance-ids i-0abc123def456
aws ec2 stop-instances --instance-ids i-0abc123def456
aws ec2 reboot-instances --instance-ids i-0abc123def456

# Terminate (permanent)
aws ec2 terminate-instances --instance-ids i-0abc123def456

# Get console output (boot logs)
aws ec2 get-console-output --instance-id i-0abc123def456 --output text
```

### Azure — Virtual Machines

```bash
# List all VMs with status
az vm list -d --output table

# Show a specific VM
az vm show -g mygroup -n myvm --show-details --output table

# Start/stop/restart/deallocate
az vm start -g mygroup -n myvm
az vm stop -g mygroup -n myvm          # Keeps allocation (still billing)
az vm deallocate -g mygroup -n myvm    # Releases compute (stops billing)
az vm restart -g mygroup -n myvm

# Delete (permanent)
az vm delete -g mygroup -n myvm --yes

# Serial console output
az vm boot-diagnostics get-boot-log -g mygroup -n myvm
```

### GCloud — Compute Engine

```bash
# List all instances across zones
gcloud compute instances list

# Filter by zone and status
gcloud compute instances list \
  --filter="zone:us-central1-a AND status=RUNNING" \
  --format="table(name,zone,machineType.basename(),networkInterfaces[0].accessConfigs[0].natIP)"

# Start/stop/reset
gcloud compute instances start myvm --zone=us-central1-a
gcloud compute instances stop myvm --zone=us-central1-a
gcloud compute instances reset myvm --zone=us-central1-a

# Delete (permanent)
gcloud compute instances delete myvm --zone=us-central1-a --quiet

# SSH directly
gcloud compute ssh myvm --zone=us-central1-a

# Get serial port output
gcloud compute instances get-serial-port-output myvm --zone=us-central1-a
```

---

## 5. Output Filtering

### AWS — JMESPath with `--query`

```bash
# Select specific fields
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
  --output table

# Filter by value
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' \
  --output text

# Sort results
aws ec2 describe-instances \
  --query 'sort_by(Reservations[].Instances[], &LaunchTime)[].[InstanceId,LaunchTime]' \
  --output table

# Use with jq for more complex processing
aws ec2 describe-instances --output json | \
  jq -r '.Reservations[].Instances[] | [.InstanceId, .State.Name, .InstanceType] | @tsv'

# Count results
aws ec2 describe-instances \
  --query 'length(Reservations[].Instances[])' \
  --output text

# Combine server-side --filters with client-side --query
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType]' \
  --output table
```

### Azure — JMESPath with `--query`

```bash
# Select specific fields
az vm list --query '[].{Name:name, RG:resourceGroup, Size:hardwareProfile.vmSize}' -o table

# Filter by value
az vm list --query "[?location=='eastus'].name" -o tsv

# Nested object access
az vm show -g mygroup -n myvm --query 'storageProfile.osDisk.diskSizeGb'

# Use with jq
az vm list -o json | jq -r '.[] | [.name, .location] | @tsv'

# Count results
az vm list --query 'length(@)'

# Combine with --output tsv for shell scripting
for vm in $(az vm list -d --query "[?powerState=='VM running'].name" -o tsv); do
  echo "Running: $vm"
done
```

### GCloud — `--filter` and `--format`

```bash
# Filter results (Python-like expressions, not JMESPath)
gcloud compute instances list \
  --filter="zone:us-central1-a AND status=RUNNING"

# Format output columns
gcloud compute instances list \
  --format="table(name,zone.basename(),machineType.basename(),status)"

# JSON output
gcloud compute instances list --format=json

# CSV output
gcloud compute instances list --format="csv(name,zone,status)"

# Extract single values
gcloud config get project --format="value(.)"

# Projections with formatting
gcloud compute instances list \
  --format="table[box](name,zone.basename(),networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)"

# Limit and sort
gcloud compute instances list --limit=10 --sort-by=name

# Combine with jq
gcloud compute instances list --format=json | jq -r '.[].name'
```

**Syntax comparison**: AWS and Azure both use JMESPath (identical syntax). GCloud
uses its own filter/format language. Backtick-quoted strings in JMESPath (`\`running\``)
are literal values; GCloud uses standard quoting.
