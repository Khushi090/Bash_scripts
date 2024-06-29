#!/bin/bash

read -p "Enter the AWS profile name (default is 'default'): " AWS_PROFILE
read -p "Enter the region (default is 'default'): " REGION
read -p "Enter the number of days to retrieve CPU utilization data for: " DAYS

AWS_PROFILE=${AWS_PROFILE:-default}
export AWS_PROFILE

AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id --profile $AWS_PROFILE)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key --profile $AWS_PROFILE)
DEFAULT_REGION=$(aws configure get region --profile $AWS_PROFILE)

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$DEFAULT_REGION" ]; then
  echo "Missing required AWS credentials or region in the profile."
  exit 1
fi

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export DEFAULT_REGION

if [ -z "$REGION" ]; then
  REGION="$DEFAULT_REGION"
fi

echo " "
echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
echo "Using profile: $AWS_PROFILE"
echo "Using region: $REGION"
echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"

get_cpu_utilization() {
  INSTANCE_ID=$1
  START_TIME=$(date -u -d "-${DAYS} days" +%Y-%m-%dT%H:%M:%S)
  END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
  aws cloudwatch get-metric-statistics --region $REGION \
    --namespace AWS/EC2 --metric-name CPUUtilization \
    --start-time $START_TIME --end-time $END_TIME --period 86400 \
    --statistics Average \
    --dimensions Name=InstanceId,Value=$INSTANCE_ID \
    --query 'Datapoints[*].Average' --output text
}

get_instance_info() {
  INSTANCE_ID=$1
  INSTANCE_NAME=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query 'Tags[0].Value' --output text)
  echo "Instance Name :- $INSTANCE_NAME"
  echo "Tags:"
  echo "====="
  aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" --query 'Tags[].[Key,Value]' --output text
}

calculate_average() {
  sum=0
  count=0
  for value in $1; do
    sum=$(echo $sum + $value | bc)
    count=$((count + 1))
  done
  if [ $count -ne 0 ]; then
    echo "scale=2; $sum / $count" | bc
  else
    echo "0"
  fi
}

INSTANCE_IDS=$(aws ec2 describe-instances --region $REGION --query 'Reservations[].Instances[].InstanceId' --output text)
declare -a instance_ids_array
instance_ids_array=($INSTANCE_IDS)

if [ ${#instance_ids_array[@]} -eq 0 ]; then
  echo " "
  echo "*-*-*-*-*-*-*-No instance IDs found*-*-*-*-*-*-*-*"
  exit 0
fi

for id in "${instance_ids_array[@]}"; do
  CPU_UTIL_VALUES=$(get_cpu_utilization $id)
  if [ "$CPU_UTIL_VALUES" != "None" ] && [ ! -z "$CPU_UTIL_VALUES" ]; then
    CPU_UTIL=$(calculate_average "$CPU_UTIL_VALUES")
    echo " "
    echo "Instance ID   :- $id"
    get_instance_info $id
    echo " "
    echo "CPU Utilization (Last $DAYS Days): $CPU_UTIL"

    CPU_UTIL_FLOAT=$(printf "%.2f" $CPU_UTIL)

    if awk "BEGIN {exit($CPU_UTIL_FLOAT >= 0 && $CPU_UTIL_FLOAT < 20)}"; then
      echo "---- < 20 -------"
      echo " "
      echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
    elif awk "BEGIN {exit($CPU_UTIL_FLOAT >= 20 && $CPU_UTIL_FLOAT < 40)}"; then
      echo "---- 20 - 40 -------"
      echo " "
      echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
    elif awk "BEGIN {exit($CPU_UTIL_FLOAT >= 40 && $CPU_UTIL_FLOAT < 60)}"; then
      echo "---- 40 - 60 -------"
      echo " "
      echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
    elif awk "BEGIN {exit($CPU_UTIL_FLOAT >= 60 && $CPU_UTIL_FLOAT < 80)}"; then
      echo "---- 60 - 80 -------"
      echo " "
      echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
    elif awk "BEGIN {exit($CPU_UTIL_FLOAT >= 80)}"; then
      echo "---- > 80 -------"
      echo " "
      echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
    fi
  fi
done

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset DEFAULT_REGION
unset AWS_PROFILE
