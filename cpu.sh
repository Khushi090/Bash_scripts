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
  # CPU_UTILIZATION=$(aws cloudwatch get-metric-statistics --region $REGION --namespace AWS/EC2 --metric-name CPUUtilization --start-time $(date -u -d "-10 minutes" +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Maximum --dimensions Name=InstanceId,Value=$INSTANCE_ID --query 'Datapoints[0].Maximum' --output text)
  INSTANCE_ID=$1
  START_TIME=$(date -u -d "-${DAYS} days" +%Y-%m-%dT%H:%M:%S)
  END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
  aws cloudwatch get-metric-statistics --region $REGION \
    --namespace AWS/EC2 --metric-name CPUUtilization \
    --start-time $START_TIME --end-time $END_TIME --period 86400 \
    --statistics Maximum \
    --dimensions Name=InstanceId,Value=$INSTANCE_ID \
    --query 'Datapoints[*].Maximum' --output text
  echo "$CPU_UTILIZATION"
}
get_instance_info() {
  INSTANCE_ID=$1  # Instance ID as input parameter
  echo "Tags:"
  echo "====="
  aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" --query 'Tags[].[Key,Value]' --output text
}
# Get the list of instance IDs
INSTANCE_IDS=$(aws ec2 describe-instances --region $REGION --query 'Reservations[].Instances[].InstanceId' --output text)

# Store the list in an array
declare -a instance_ids_array
instance_ids_array=($INSTANCE_IDS)

#Check Instance 

if [ ${#instance_ids_array[@]} -eq 0 ]; then
  echo " "
  echo "*-*-*-*-*-*-*-No instance IDs found*-*-*-*-*-*-*-*"
  exit 0
fi



for id in "${instance_ids_array[@]}"; do
  CPU_UTIL=$(get_cpu_utilization $id)
  if [ "$CPU_UTIL" != "None" ] && [ ! -z "$CPU_UTIL" ]; then
  echo " "
  echo "Instance IDs:- $id";
  echo " "
  #echo "CPU Utilization (Last $DAYS Days):- $CPU_UTIL ";
  echo -n "CPU Utilization (Last $DAYS Days):-  ";
  # get_instance_info $id
    if awk "BEGIN {exit!($CPU_UTIL > 0 && $CPU_UTIL < 0.20)}"; then
      echo "---- <20 -------"
      echo " "
      get_instance_info $id
      echo " "
      echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
      echo " "
    fi
    if awk "BEGIN {exit!($CPU_UTIL > 0.20 && $CPU_UTIL < 0.40)}"; then
      echo "---- 20 - 40 -------" 
      echo " "     
      get_instance_info $id
      echo " "
      echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
      echo " "
    fi
    if awk "BEGIN {exit!($CPU_UTIL > 0.40 && $CPU_UTIL < 0.60)}"; then
      echo "---- 40 - 60 -------" 
      echo " "     
      get_instance_info $id
      echo " "
      echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
      echo " "
    fi
    if awk "BEGIN {exit!($CPU_UTIL > 0.60 && $CPU_UTIL < 0.80)}"; then
      echo "---- 60 - 80 -------"
      echo " "
      get_instance_info $id
      echo " "
      echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
      echo " "
    fi
    if awk "BEGIN {exit!($CPU_UTIL > 0.80 )}"; then
      echo "---- >80-------"  
      echo " "   
      get_instance_info $id
      echo " "
      echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
      echo " "
    fi
  fi
done

# Unset the environment variables after use
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset DEFAULT_REGION
unset AWS_PROFILE
