#!/bin/bash

read -p "Enter the AWS profile name (default is 'default'): " AWS_PROFILE
read -p "Enter the region (default is 'default'): " REGION

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

get_idle_time_category() {
    local last_used_date=$1
    local current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local idle_time_seconds=$(( $(date -d "$current_date" +%s) - $(date -d "$last_used_date" +%s) ))

    local idle_days=$(( idle_time_seconds / 86400 ))

    if [ $idle_days -gt 30 ]; then
        echo "> month"
    elif [ $idle_days -ge 7 ]; then
        echo "< month"
    else
        echo "< week"
    fi
}

# Function to get Instance Name
get_instance_name() {
    local instance_id=$1
    local instance_name=$(aws ec2 describe-instances --region "$REGION" --profile "$AWS_PROFILE" --instance-ids "$instance_id" --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value' --output text)
    echo "$instance_name"
}

# Function to get Snapshot Name
get_snapshot_name() {
    local snapshot_id=$1
    local snapshot_name=$(aws ec2 describe-snapshots --region "$REGION" --profile "$AWS_PROFILE" --snapshot-ids "$snapshot_id" --query 'Snapshots[*].Tags[?Key==`Name`].Value' --output text)
    echo "$snapshot_name"
}

# Function to get EIP Name
get_eip_name() {
    local allocation_id=$1
    local eip_name=$(aws ec2 describe-addresses --region "$REGION" --profile "$AWS_PROFILE" --allocation-ids "$allocation_id" --query 'Addresses[*].Tags[?Key==`Name`].Value' --output text)
    echo "$eip_name"
}

# Function to get AMI Name
get_ami_name() {
    local ami_id=$1
    local ami_name=$(aws ec2 describe-images --region "$REGION" --profile "$AWS_PROFILE" --image-ids "$ami_id" --query 'Images[*].Name' --output text)
    echo "$ami_name"
}

check_ec2_last_working_time_all() {
    echo " "
    echo "Checking EC2 instances..."
    echo "========================="
    INSTANCE_IDS=$(aws ec2 describe-instances --region "$REGION" --profile "$AWS_PROFILE" --query 'Reservations[*].Instances[*].InstanceId' --output text)

    if [ $? -ne 0 ]; then
        echo "Failed to fetch instance information. Please check your AWS CLI configuration and permissions."
        exit 1
    fi

    if [[ -z "$INSTANCE_IDS" ]]; then
        echo "No instances found in region $REGION."
    else
        for INSTANCE_ID in $INSTANCE_IDS; do
            INSTANCE_INFO=$(aws ec2 describe-instances --region "$REGION" --profile "$AWS_PROFILE" --instance-ids "$INSTANCE_ID" --query 'Reservations[*].Instances[*].{State:State.Name,LaunchTime:LaunchTime}' --output json)

            INSTANCE_STATE=$(echo "$INSTANCE_INFO" | jq -r '.[0][0].State')
            LAUNCH_TIME=$(echo "$INSTANCE_INFO" | jq -r '.[0][0].LaunchTime')

            if [[ "$INSTANCE_STATE" == "stopped" ]]; then
                IDLE_CATEGORY=$(get_idle_time_category "$LAUNCH_TIME")
                INSTANCE_NAME=$(get_instance_name "$INSTANCE_ID")

                if [[ -z "$INSTANCE_NAME" ]]; then
                    INSTANCE_NAME="Name not found"
                fi

                echo "-------------------------------------"
                echo "Instance Name: $INSTANCE_NAME"
                echo "Instance ID: $INSTANCE_ID"
                echo "Idle Time Category: $IDLE_CATEGORY"
                echo "-------------------------------------"
            fi
        done
    fi
}

check_last_ami_use() {
    echo " "
    echo "Fetching AMI usage details..."
    echo "============================="
    AMIS=$(aws ec2 describe-images --region "$REGION" --profile "$AWS_PROFILE" --owners self --query 'Images[*].{ImageId:ImageId,CreationDate:CreationDate}' --output json)
    
    if [ $? -ne 0 ]; then
        echo "Failed to fetch AMI information. Please check your AWS CLI configuration and permissions."
        exit 1
    fi

    if [[ -z "$AMIS" || "$AMIS" == "[]" ]]; then
        echo "No AMIs found in region $REGION."
    else
        echo "$AMIS" | jq -r '.[] | "\(.ImageId) \(.CreationDate)"' | while read -r ami; do
            AMI_ID=$(echo "$ami" | cut -d ' ' -f 1)
            CREATION_DATE=$(echo "$ami" | cut -d ' ' -f 2)
            
            IDLE_CATEGORY=$(get_idle_time_category "$CREATION_DATE")
            AMI_NAME=$(get_ami_name "$AMI_ID")

            if [[ -z "$AMI_NAME" ]]; then
                AMI_NAME="Name not found"
            fi

            echo " "
            echo "AMI Name: $AMI_NAME"
            echo "AMI ID: $AMI_ID"
            echo "Idle Time Category: $IDLE_CATEGORY"
            echo "-------------------------------------"
        done
    fi
}

check_last_snapshot_use() {
    echo " "
    echo "Fetching Snapshot usage details..."
    echo "==================================="
    SNAPSHOTS=$(aws ec2 describe-snapshots --region "$REGION" --profile "$AWS_PROFILE" --owner-ids self --query 'Snapshots[*].{SnapshotId:SnapshotId,StartTime:StartTime}' --output json)
    
    if [ $? -ne 0 ]; then
        echo "Failed to fetch Snapshot information. Please check your AWS CLI configuration and permissions."
        exit 1
    fi

    if [[ -z "$SNAPSHOTS" || "$SNAPSHOTS" == "[]" ]]; then
        echo "No Snapshots found in region $REGION."
    else
        echo "$SNAPSHOTS" | jq -r '.[] | "\(.SnapshotId) \(.StartTime)"' | while read -r snapshot; do
            SNAPSHOT_ID=$(echo "$snapshot" | cut -d ' ' -f 1)
            START_TIME=$(echo "$snapshot" | cut -d ' ' -f 2)
            
            IDLE_CATEGORY=$(get_idle_time_category "$START_TIME")
            SNAPSHOT_NAME=$(get_snapshot_name "$SNAPSHOT_ID")

            if [[ -z "$SNAPSHOT_NAME" ]]; then
                SNAPSHOT_NAME="Name not found"
            fi

            echo " "
            echo "Snapshot Name: $SNAPSHOT_NAME"
            echo "Snapshot ID: $SNAPSHOT_ID"
            echo "Idle Time Category: $IDLE_CATEGORY"
            echo "-------------------------------------"
        done
    fi
}

check_last_ebs_use() {
    echo " "
    echo "Fetching EBS volume usage details..."
    echo "===================================="
    VOLUMES=$(aws ec2 describe-volumes --region "$REGION" --profile "$AWS_PROFILE" --query 'Volumes[*].{VolumeId:VolumeId,CreateTime:CreateTime}' --output json)
    
    if [ $? -ne 0 ]; then
        echo "Failed to fetch EBS volume information. Please check your AWS CLI configuration and permissions."
        exit 1
    fi

    if [[ -z "$VOLUMES" || "$VOLUMES" == "[]" ]]; then
        echo "No EBS volumes found in region $REGION."
    else
        echo "$VOLUMES" | jq -r '.[] | "\(.VolumeId) \(.CreateTime)"' | while read -r volume; do
            VOLUME_ID=$(echo "$volume" | cut -d ' ' -f 1)
            CREATE_TIME=$(echo "$volume" | cut -d ' ' -f 2)
            
            IDLE_CATEGORY=$(get_idle_time_category "$CREATE_TIME")

            echo " "
            echo "Volume ID: $VOLUME_ID"
            echo "Idle Time Category: $IDLE_CATEGORY"
            echo "-------------------------------------"
        done
    fi
}

check_last_elastic_ip_use() {
    echo " "
    echo "Fetching Elastic IP usage details..."
    echo "===================================="
    EIPS=$(aws ec2 describe-addresses --region "$REGION" --profile "$AWS_PROFILE" --query 'Addresses[*].{PublicIp:PublicIp,AllocationId:AllocationId,AssociationId:AssociationId,InstanceId:InstanceId}' --output json)
    
    if [ $? -ne 0 ]; then
        echo "Failed to fetch Elastic IP information. Please check your AWS CLI configuration and permissions."
        exit 1
    fi

    if [[ -z "$EIPS" || "$EIPS" == "[]" ]]; then
        echo "No Elastic IPs found in region $REGION."
    else
        echo "$EIPS" | jq -r '.[] | select(.InstanceId == null) | "\(.AllocationId) \(.PublicIp)"' | while read -r eip; do
            ALLOCATION_ID=$(echo "$eip" | cut -d ' ' -f 1)
            PUBLIC_IP=$(echo "$eip" | cut -d ' ' -f 2)

            EIP_NAME=$(get_eip_name "$ALLOCATION_ID")
            # Assuming the AllocationId is the creation date, which is not accurate. Ideally, you should have the actual date.
            ALLOCATION_DATE=$(aws ec2 describe-addresses --region "$REGION" --profile "$AWS_PROFILE" --allocation-ids "$ALLOCATION_ID" --query 'Addresses[*].AllocationTime' --output text)

            IDLE_CATEGORY=$(get_idle_time_category "$ALLOCATION_DATE")

            if [[ -z "$EIP_NAME" ]]; then
                EIP_NAME="Name not found"
            fi

            echo " "
            echo "Elastic IP Name: $EIP_NAME"
            echo "Elastic IP: $PUBLIC_IP"
            echo "Idle Time Category: $IDLE_CATEGORY"
            echo "-------------------------------------"
        done
    fi
}

check_ec2_last_working_time_all
check_last_ami_use
check_last_snapshot_use
check_last_ebs_use
check_last_elastic_ip_use

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset DEFAULT_REGION
unset AWS_PROFILE
