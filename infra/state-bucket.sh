#!/usr/bin/env bash
# Creates the S3 bucket that holds Terraform state for every stack. Run once per AWS account;
# running it again only re-applies the settings.
# Usage: AWS_PROFILE=<profile> ./state-bucket.sh
set -euo pipefail

BUCKET="${BUCKET:-ananda-raj-app-tfstate-ap-south-1}"
REGION="${REGION:-ap-south-1}"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket $BUCKET exists; updating settings."
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" >/dev/null
  aws s3api wait bucket-exists --bucket "$BUCKET"
  echo "Created $BUCKET."
fi

aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-ownership-controls --bucket "$BUCKET" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'

aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Versions let you roll back a bad state write; old ones expire after 90 days.
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled

aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" --lifecycle-configuration \
  '{"Rules":[{"ID":"expire-old-state-versions","Status":"Enabled","Filter":{},"NoncurrentVersionExpiration":{"NoncurrentDays":90}}]}'

aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$(cat <<JSON
{"Version":"2012-10-17","Statement":[{"Sid":"DenyInsecureTransport","Effect":"Deny","Principal":"*","Action":"s3:*",
"Resource":["arn:aws:s3:::$BUCKET","arn:aws:s3:::$BUCKET/*"],"Condition":{"Bool":{"aws:SecureTransport":"false"}}}]}
JSON
)"

aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging 'TagSet=[{Key=Purpose,Value=terraform-state},{Key=ManagedBy,Value=state-bucket.sh}]'

echo "State bucket ready: s3://$BUCKET ($REGION)"
