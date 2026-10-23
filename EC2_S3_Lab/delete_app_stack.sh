#!/bin/bash
set -e
export $(grep -v '^#' .env | xargs)
export AWS_PAGER=""

for ID_FILE in uploader_instance_id.txt viewer_instance_id.txt; do
  if [[ -f "$ID_FILE" ]]; then
    INSTANCE_ID=$(cat "$ID_FILE")
    echo "Terminating instance: $INSTANCE_ID"
    aws ec2 terminate-instances \
      --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
    aws ec2 wait instance-terminated \
      --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
    rm -f "$ID_FILE"
  else
    echo "No $ID_FILE found - skipping."
  fi
done

echo "== Deleting launch templates =="
aws ec2 delete-launch-template \
  --launch-template-name "$UPLOADER_LT_NAME" \
  --region "$AWS_REGION" 2>/dev/null || true

aws ec2 delete-launch-template \
  --launch-template-name "$VIEWER_LT_NAME" \
  --region "$AWS_REGION" 2>/dev/null || true

echo "== Removing IAM instance profiles and roles =="
aws iam remove-role-from-instance-profile \
  --instance-profile-name "$UPLOADER_PROFILE_NAME" \
  --role-name "$UPLOADER_ROLE_NAME" 2>/dev/null || true

aws iam delete-instance-profile \
  --instance-profile-name "$UPLOADER_PROFILE_NAME" 2>/dev/null || true

aws iam delete-role-policy \
  --role-name "$UPLOADER_ROLE_NAME" \
  --policy-name "${UPLOADER_ROLE_NAME}-policy" 2>/dev/null || true

aws iam delete-role-policy \
  --role-name "$UPLOADER_ROLE_NAME" \
  --policy-name uploader-put-only 2>/dev/null || true

aws iam delete-role \
  --role-name "$UPLOADER_ROLE_NAME" 2>/dev/null || true

aws iam remove-role-from-instance-profile \
  --instance-profile-name "$VIEWER_PROFILE_NAME" \
  --role-name "$VIEWER_ROLE_NAME" 2>/dev/null || true

aws iam delete-instance-profile \
  --instance-profile-name "$VIEWER_PROFILE_NAME" 2>/dev/null || true

aws iam delete-role-policy \
  --role-name "$VIEWER_ROLE_NAME" \
  --policy-name "${VIEWER_ROLE_NAME}-policy" 2>/dev/null || true

aws iam delete-role \
  --role-name "$VIEWER_ROLE_NAME" 2>/dev/null || true

echo "== Emptying and deleting S3 bucket =="
aws s3 rm "s3://$BUCKET_NAME" \
  --recursive --region "$AWS_REGION" 2>/dev/null || true

aws s3api delete-bucket \
  --bucket "$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null || true

echo "Cleanup complete."
