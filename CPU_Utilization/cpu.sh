#!/bin/bash

CONFIG_FILE="config.properties"

if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  echo "Configuration file not found!"
  exit 1
fi

read -p "Enter the start date (YYYY-MM-DD): " START_DATE
read -p "Enter the end date (YYYY-MM-DD): " END_DATE


if [ -z "$START_DATE" ] || [ -z "$END_DATE" ]; then
  echo "Start date and end date are required."
  exit 1
fi


if [ -z "${AWS_PROFILE}" ]; then
  echo "AWS_PROFILE not set in config.properties"
  exit 1
fi

if [ -z "${REGION}" ]; then
  echo "REGION not set in config.properties"
  exit 1
fi

AWS_PROFILES=("${AWS_PROFILE[@]}")
REGIONS=("${REGION[@]}")

for PROFILE in "${AWS_PROFILES[@]}"; do
  export AWS_PROFILE="$PROFILE"
  
  AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id --profile $AWS_PROFILE)
  AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key --profile $AWS_PROFILE)
  
  if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Missing required AWS credentials in profile $AWS_PROFILE."
    continue
  fi

  for REGION in "${REGIONS[@]}"; do
    echo " "
    echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
    echo "Using profile: $AWS_PROFILE"
    echo "Using region: $REGION"
    echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"

    
    echo "Debug: AWS_PROFILE=$AWS_PROFILE, REGION=$REGION"

    get_cpu_utilization() {
      INSTANCE_ID=$1
      START_TIME="${START_DATE}T00:00:00Z"
      END_TIME="${END_DATE}T23:59:59Z"
      aws cloudwatch get-metric-statistics --profile $AWS_PROFILE --region $REGION \
        --namespace AWS/EC2 --metric-name CPUUtilization \
        --start-time $START_TIME --end-time $END_TIME --period 86400 \
        --statistics Average \
        --dimensions Name=InstanceId,Value=$INSTANCE_ID \
        --output text | awk '{ print $2 }' | xargs -n1 printf "%.2f\n"
    }

    get_instance_info() {
      INSTANCE_ID=$1
      INSTANCE_NAME=$(aws ec2 describe-tags --profile $AWS_PROFILE --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query 'Tags[0].Value' --output text)
      echo "Instance Name :- $INSTANCE_NAME"
      echo "Tags:"
      echo "====="
      aws ec2 describe-tags --profile $AWS_PROFILE --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" --query 'Tags[].[Key,Value]' --output text
    }

    INSTANCE_IDS=$(aws ec2 describe-instances --profile $AWS_PROFILE --region $REGION --query 'Reservations[].Instances[].InstanceId' --output text)
    declare -a instance_ids_array
    instance_ids_array=($INSTANCE_IDS)

    
    echo "Debug: Instance IDs found in profile $AWS_PROFILE and region $REGION: ${instance_ids_array[@]}"

    if [ ${#instance_ids_array[@]} -eq 0 ]; then
      echo "No instances found in profile $AWS_PROFILE and region $REGION."
      continue
    fi

    for id in "${instance_ids_array[@]}"; do
      CPU_UTIL=$(get_cpu_utilization $id)
      if [ "$CPU_UTIL" != "None" ] && [ ! -z "$CPU_UTIL" ]; then
        echo " "
        echo "Instance ID   :- $id"
        get_instance_info $id
        
        
        total_sum=0
        total_count=0
        IFS=$'\n' read -r -d '' -a cpu_array <<< "$CPU_UTIL"
        for value in "${cpu_array[@]}"; do
          total_sum=$(echo "$total_sum + $value" | bc)
          total_count=$((total_count + 1))
        done
        
        if [ $total_count -gt 0 ]; then
          total_average=$(echo "scale=2; $total_sum / $total_count" | bc)
          echo "Total average CPU utilization for instance $id (From $START_DATE to $END_DATE): $total_average"
        fi
      fi
    done
  done
done

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset DEFAULT_REGION
unset AWS_PROFILE
