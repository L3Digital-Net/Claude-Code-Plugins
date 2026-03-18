# Cloud CLI Side-by-Side Cheatsheet

Equivalent operations across AWS CLI, Azure CLI, and Google Cloud CLI.

---

## Authentication

| Task | AWS CLI | Azure CLI | Google Cloud CLI |
|------|---------|-----------|------------------|
| Interactive login | `aws configure` | `az login` | `gcloud auth login` |
| SSO login | `aws sso login --profile NAME` | N/A (use `az login` with browser) | N/A (use `gcloud auth login`) |
| Service account/principal | Export `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` | `az login --service-principal -u ID -p SECRET --tenant TID` | `gcloud auth activate-service-account --key-file=key.json` |
| Application default creds | N/A (SDKs use credential chain) | N/A (token cache at `~/.azure`) | `gcloud auth application-default login` |
| Managed/instance identity | Automatic via instance metadata (IMDS) | `az login --identity` | Automatic via metadata server |
| Device code flow | N/A | `az login --use-device-code` | `gcloud auth login --no-launch-browser` |
| Who am I | `aws sts get-caller-identity` | `az account show` | `gcloud config list account` |
| List authenticated accounts | `aws configure list-profiles` | `az account list -o table` | `gcloud auth list` |
| Logout/revoke | `rm ~/.aws/credentials` (manual) | `az logout` | `gcloud auth revoke` |

## Profile/Project/Subscription Switching

| Task | AWS CLI | Azure CLI | Google Cloud CLI |
|------|---------|-----------|------------------|
| Set default profile/project | `export AWS_PROFILE=myprofile` | `az account set -s SUB_ID` | `gcloud config set project PROJECT_ID` |
| Per-command override | `--profile myprofile` | `--subscription SUB_ID` | `--project PROJECT_ID` |
| List profiles/subscriptions | `aws configure list-profiles` | `az account list -o table` | `gcloud config configurations list` |
| Create named config | Edit `~/.aws/config` manually | N/A (one active subscription) | `gcloud config configurations create NAME` |
| Switch named config | `export AWS_PROFILE=name` | `az account set -s name` | `gcloud config configurations activate NAME` |
| Set default region | `aws configure set region us-east-1` | `az config set defaults.location=eastus` | `gcloud config set compute/region us-central1` |
| View current config | `aws configure list` | `az config get` | `gcloud config list` |

## Compute (VMs/Instances)

| Task | AWS CLI | Azure CLI | Google Cloud CLI |
|------|---------|-----------|------------------|
| List instances | `aws ec2 describe-instances --output table` | `az vm list -o table` | `gcloud compute instances list` |
| Create instance | `aws ec2 run-instances --image-id ami-xxx --instance-type t3.micro --key-name mykey` | `az vm create -g GROUP -n NAME --image Ubuntu2204 --size Standard_B1s` | `gcloud compute instances create NAME --zone=ZONE --machine-type=e2-micro` |
| Start instance | `aws ec2 start-instances --instance-ids i-xxx` | `az vm start -g GROUP -n NAME` | `gcloud compute instances start NAME --zone=ZONE` |
| Stop instance | `aws ec2 stop-instances --instance-ids i-xxx` | `az vm stop -g GROUP -n NAME` | `gcloud compute instances stop NAME --zone=ZONE` |
| Terminate/delete | `aws ec2 terminate-instances --instance-ids i-xxx` | `az vm delete -g GROUP -n NAME --yes` | `gcloud compute instances delete NAME --zone=ZONE --quiet` |
| SSH into instance | `ssh -i key.pem user@IP` (manual) | `az ssh vm -g GROUP -n NAME` | `gcloud compute ssh NAME --zone=ZONE` |
| Instance details | `aws ec2 describe-instances --instance-ids i-xxx` | `az vm show -g GROUP -n NAME` | `gcloud compute instances describe NAME --zone=ZONE` |
| List regions/zones | `aws ec2 describe-regions --output table` | `az account list-locations -o table` | `gcloud compute zones list` |

## Storage (S3 / Blob / GCS)

| Task | AWS CLI | Azure CLI | Google Cloud CLI |
|------|---------|-----------|------------------|
| List buckets/containers | `aws s3 ls` | `az storage container list --account-name ACCT -o table` | `gcloud storage ls` |
| Create bucket/container | `aws s3 mb s3://my-bucket` | `az storage container create --account-name ACCT -n mycontainer` | `gcloud storage buckets create gs://my-bucket --location=US` |
| Upload file | `aws s3 cp file.txt s3://bucket/` | `az storage blob upload --account-name ACCT -c CONTAINER -f file.txt -n file.txt` | `gcloud storage cp file.txt gs://bucket/` |
| Download file | `aws s3 cp s3://bucket/file.txt ./` | `az storage blob download --account-name ACCT -c CONTAINER -n file.txt -f ./file.txt` | `gcloud storage cp gs://bucket/file.txt ./` |
| Sync directory | `aws s3 sync ./dir s3://bucket/prefix/` | `az storage blob sync -c CONTAINER --account-name ACCT -s ./dir` | `gcloud storage rsync ./dir gs://bucket/prefix/` |
| Delete object | `aws s3 rm s3://bucket/file.txt` | `az storage blob delete --account-name ACCT -c CONTAINER -n file.txt` | `gcloud storage rm gs://bucket/file.txt` |
| Delete bucket (force) | `aws s3 rb s3://bucket --force` | `az storage container delete --account-name ACCT -n CONTAINER` | `gcloud storage rm -r gs://bucket/` |
| Presigned/signed URL | `aws s3 presign s3://bucket/file --expires-in 3600` | `az storage blob generate-sas` (SAS token) | `gcloud storage sign-url gs://bucket/file --duration=1h` |
| List objects | `aws s3 ls s3://bucket/prefix/` | `az storage blob list --account-name ACCT -c CONTAINER -o table` | `gcloud storage ls gs://bucket/prefix/` |

## Networking

| Task | AWS CLI | Azure CLI | Google Cloud CLI |
|------|---------|-----------|------------------|
| List VPCs/VNets | `aws ec2 describe-vpcs --output table` | `az network vnet list -o table` | `gcloud compute networks list` |
| List subnets | `aws ec2 describe-subnets --output table` | `az network vnet subnet list -g GROUP --vnet-name VNET -o table` | `gcloud compute networks subnets list` |
| List security groups/NSGs | `aws ec2 describe-security-groups --output table` | `az network nsg list -o table` | `gcloud compute firewall-rules list` |
| Add firewall rule | `aws ec2 authorize-security-group-ingress --group-id sg-xxx --protocol tcp --port 443 --cidr 0.0.0.0/0` | `az network nsg rule create -g GROUP --nsg-name NSG -n AllowHTTPS --priority 100 --destination-port-ranges 443 --access Allow --protocol Tcp` | `gcloud compute firewall-rules create allow-https --allow=tcp:443 --source-ranges=0.0.0.0/0` |
| List public IPs | `aws ec2 describe-addresses --output table` | `az network public-ip list -o table` | `gcloud compute addresses list` |
| DNS zones | `aws route53 list-hosted-zones` | `az network dns zone list -o table` | `gcloud dns managed-zones list` |

## IAM / Identity

| Task | AWS CLI | Azure CLI | Google Cloud CLI |
|------|---------|-----------|------------------|
| List users | `aws iam list-users --output table` | `az ad user list -o table` | `gcloud identity groups memberships list` (Workspace) |
| Create service account | `aws iam create-user --user-name svc-name` + `aws iam create-access-key` | `az ad sp create-for-rbac --name svc-name` | `gcloud iam service-accounts create sa-name` |
| List roles/policies | `aws iam list-policies --scope Local --output table` | `az role definition list -o table` | `gcloud iam roles list` |
| Attach role/policy | `aws iam attach-user-policy --user-name USER --policy-arn ARN` | `az role assignment create --assignee USER --role "Contributor" --scope /subscriptions/SUB` | `gcloud projects add-iam-policy-binding PROJECT --member='user:EMAIL' --role='roles/editor'` |
| View current identity | `aws sts get-caller-identity` | `az ad signed-in-user show` | `gcloud auth list` |
| List service account keys | `aws iam list-access-keys --user-name USER` | `az ad sp credential list --id SP_ID` | `gcloud iam service-accounts keys list --iam-account=SA_EMAIL` |
