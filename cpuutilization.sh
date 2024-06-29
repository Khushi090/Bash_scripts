#!/bin/bash

REGION="us-east-2"  # Replace with your desired region

get_cpu_utilization() {
  INSTANCE_ID=$1  # Instance ID as input parameter

  CPU_UTILIZATION=$(aws cloudwatch get-metric-statistics --region $REGION --namespace AWS/EC2 --metric-name CPUUtilization --start-time $(date -u -d "-10 minutes" +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Maximum --dimensions Name=InstanceId,Value=$INSTANCE_ID --query 'Datapoints[0].Maximum' --output text)
  echo "$CPU_UTILIZATION"
}

get_instance_info() {
  INSTANCE_ID=$1  # Instance ID as input parameter
  echo "Tags:"
  aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" --query 'Tags[].[Key,Value]' --output text
}


# Get the list of instance IDs
INSTANCE_IDS=$(aws ec2 describe-instances --region $REGION --query 'Reservations[].Instances[].InstanceId' --output text)

# Store the list in an array
declare -a instance_ids_array

instance_ids_array=($INSTANCE_IDS)

# Print the array to verify
echo "Instance IDs:"
for id in "${instance_ids_array[@]}"; do
  
  CPU_UTIL=$(get_cpu_utilization $id)
  if [ "$CPU_UTIL" != "None" ] && [ ! -z "$CPU_UTIL" ]; then 
  echo "$id";
  echo ${CPU_UTIL};
  # get_instance_info $id
    if awk "BEGIN {exit!($CPU_UTIL > 0 && $CPU_UTIL < 0.20)}"; then
      echo "---- <20 -------"
      get_instance_info $id
    fi
    if awk "BEGIN {exit!($CPU_UTIL > 0.20 && $CPU_UTIL < 0.40)}"; then
      echo "---- 20 - 40 -------"
      get_instance_info $id
    fi  
    if awk "BEGIN {exit!($CPU_UTIL > 0.40 && $CPU_UTIL < 0.60)}"; then
      echo "---- 40 - 60 -------"
      get_instance_info $id
    fi
    if awk "BEGIN {exit!($CPU_UTIL > 0.60 && $CPU_UTIL < 0.80)}"; then
      echo "---- 60 - 80 -------"
      get_instance_info $id
    fi
    if awk "BEGIN {exit!($CPU_UTIL > 0.80 )}"; then
      echo "---- >80-------"
      get_instance_info $id
    fi

  fi  
  
done















