#!/bin/bash

# Load configuration from config.properties
load_config() {
    if [ -f config.properties ]; then
        echo "Loading configuration from config.properties..."
        . config.properties
    else
        echo "No config.properties file found. Exiting..."
        exit 1
    fi
}

# Function to calculate idle time category
get_idle_time_category() {
    local last_used_date=$1
    local current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local idle_time_seconds=$(( $(date -d "$current_date" +%s) - $(date -d "$last_used_date" +%s) ))

    local idle_days=$(( idle_time_seconds / 86400 ))

    if [ $idle_days -gt 30 ]; then
        echo "> month"
        echo "$idle_days days"
    elif [ $idle_days -ge 7 ]; then
        echo "< month"
        echo "$idle_days days"
    elif [ $idle_days -ge 1 ]; then
        echo "< week"
        echo "$idle_days days"
    else
        local idle_hours=$(( (idle_time_seconds % 86400) / 3600 ))
        local idle_minutes=$(( (idle_time_seconds % 3600) / 60 ))

        if [ $idle_hours -gt 0 ]; then
            echo "< day"
            echo "$idle_hours hours $idle_minutes minutes"
        else
            echo "< hour"
            echo "$idle_minutes minutes"
        fi
    fi
}

# Function to convert UTC to GMT+5:30
convert_to_gmt530() {
    local utc_time=$1
    local gmt530_time=$(date -u -d "$utc_time 5 hours 30 minutes" +"%Y-%m-%dT%H:%M:%S%:z")
    echo "$gmt530_time"
}

# Function to get instance name by instance ID
get_instance_name() {
    local instance_id=$1
    local instance_name=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' --output text --region "$REGION" --profile "$AWS_PROFILE")
    echo "$instance_name"
}

# Function to get AMI name by AMI ID
get_ami_name() {
    local ami_id=$1
    local ami_name=$(aws ec2 describe-images --image-ids "$ami_id" --query 'Images[].Name' --output text --region "$REGION" --profile "$AWS_PROFILE")
    echo "$ami_name"
}

# Function to get snapshot name by snapshot ID
get_snapshot_name() {
    local snapshot_id=$1
    local snapshot_name=$(aws ec2 describe-snapshots --snapshot-ids "$snapshot_id" --query 'Snapshots[].Tags[?Key==`Name`].Value' --output text --region "$REGION" --profile "$AWS_PROFILE")
    echo "$snapshot_name"
}

# Function to get EBS volume name by volume ID
get_volume_name() {
    local volume_id=$1
    local volume_name=$(aws ec2 describe-volumes --volume-ids "$volume_id" --query 'Volumes[].Tags[?Key==`Name`].Value' --output text --region "$REGION" --profile "$AWS_PROFILE")
    echo "$volume_name"
}

# Function to get EIP name by allocation ID
get_eip_name() {
    local allocation_id=$1
    local eip_name=$(aws ec2 describe-addresses --allocation-ids "$allocation_id" --query 'Addresses[].Tags[?Key==`Name`].Value' --output text --region "$REGION" --profile "$AWS_PROFILE")
    echo "$eip_name"
}

# Function to get EBS volume creation time by volume ID
get_volume_creation_time() {
    local volume_id=$1
    local create_time=$(aws ec2 describe-volumes --volume-ids "$volume_id" --query 'Volumes[].CreateTime' --output text --region "$REGION" --profile "$AWS_PROFILE")
    echo "$create_time"
}

# Function to check EC2 instances
check_ec2_instances() {
    echo "Checking EC2 instances..."
    echo "========================="
    INSTANCE_IDS=$(aws ec2 describe-instances --filters Name=instance-state-name,Values=stopped --query 'Reservations[].Instances[].InstanceId' --output text --region "$REGION" --profile "$AWS_PROFILE")

    if [ -z "$INSTANCE_IDS" ]; then
        echo "No stopped instances found in region $REGION."
    else
        for instance_id in $INSTANCE_IDS; do
            INSTANCE_NAME=$(get_instance_name "$instance_id")
            LAST_USED=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[].Instances[].LaunchTime' --output text --region "$REGION" --profile "$AWS_PROFILE")

            if [ -n "$LAST_USED" ]; then
                IDLE_CATEGORY=$(get_idle_time_category "$LAST_USED")
                echo "-------------------------------------"
                echo "Instance Name: $INSTANCE_NAME"
                echo "Instance ID: $instance_id"
                echo "Idle Time Category: $(echo "$IDLE_CATEGORY" | head -n 1)"
                echo "Idle Time Detail: $(echo "$IDLE_CATEGORY" | tail -n 1)"
                LAST_USED_GMT530=$(convert_to_gmt530 "$LAST_USED")
                echo "Last Used/Stopped Time (GMT+5:30): $LAST_USED_GMT530"
            fi
        done
    fi
}

# Function to check AMIs
check_amis() {
    echo ""
    echo "Fetching AMI usage details..."
    echo "============================="
    AMI_IDS=$(aws ec2 describe-images --owners self --query 'Images[].ImageId' --output text --region "$REGION" --profile "$AWS_PROFILE")

    if [ -z "$AMI_IDS" ]; then
        echo "No AMIs found in region $REGION."
    else
        for ami_id in $AMI_IDS; do
            AMI_NAME=$(get_ami_name "$ami_id")
            CREATION_DATE=$(aws ec2 describe-images --image-ids "$ami_id" --query 'Images[].CreationDate' --output text --region "$REGION" --profile "$AWS_PROFILE")

            if [ -n "$CREATION_DATE" ]; then
                IDLE_CATEGORY=$(get_idle_time_category "$CREATION_DATE")
                echo "-------------------------------------"
                echo "AMI Name: $AMI_NAME"
                echo "AMI ID: $ami_id"
                echo "Idle Time Category: $(echo "$IDLE_CATEGORY" | head -n 1)"
                echo "Idle Time Detail: $(echo "$IDLE_CATEGORY" | tail -n 1)"
                CREATION_DATE_GMT530=$(convert_to_gmt530 "$CREATION_DATE")
                echo "Creation Date (GMT+5:30): $CREATION_DATE_GMT530"
            fi
        done
    fi
}

# Function to check snapshots
check_snapshots() {
    echo ""
    echo "Fetching Snapshot usage details..."
    echo "==================================="
    SNAPSHOT_IDS=$(aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[].SnapshotId' --output text --region "$REGION" --profile "$AWS_PROFILE")

    if [ -z "$SNAPSHOT_IDS" ]; then
        echo "No Snapshots found in region $REGION."
    else
        for snapshot_id in $SNAPSHOT_IDS; do
            SNAPSHOT_NAME=$(get_snapshot_name "$snapshot_id")
            START_TIME=$(aws ec2 describe-snapshots --snapshot-ids "$snapshot_id" --query 'Snapshots[].StartTime' --output text --region "$REGION" --profile "$AWS_PROFILE")

            if [ -n "$START_TIME" ]; then
                IDLE_CATEGORY=$(get_idle_time_category "$START_TIME")
                echo "-------------------------------------"
                echo "Snapshot Name: $SNAPSHOT_NAME"
                echo "Snapshot ID: $snapshot_id"
                echo "Idle Time Category: $(echo "$IDLE_CATEGORY" | head -n 1)"
                echo "Idle Time Detail: $(echo "$IDLE_CATEGORY" | tail -n 1)"
                START_TIME_GMT530=$(convert_to_gmt530 "$START_TIME")
                echo "Start Time (GMT+5:30): $START_TIME_GMT530"
            fi
        done
    fi
}

# Function to check EBS volumes
check_ebs_volumes() {
    echo ""
    echo "Fetching EBS volume usage details..."
    echo "===================================="
    VOLUME_IDS=$(aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId' --output text --region "$REGION" --profile "$AWS_PROFILE")

    if [ -z "$VOLUME_IDS" ]; then
        echo "No unused EBS volumes found in region $REGION."
    else
        for volume_id in $VOLUME_IDS; do
            VOLUME_NAME=$(get_volume_name "$volume_id")
            CREATE_TIME=$(get_volume_creation_time "$volume_id")

            if [ -n "$CREATE_TIME" ]; then
                IDLE_CATEGORY=$(get_idle_time_category "$CREATE_TIME")
                echo "-------------------------------------"
                echo "Volume Name: $VOLUME_NAME"
                echo "Volume ID: $volume_id"
                echo "Idle Time Category: $(echo "$IDLE_CATEGORY" | head -n 1)"
                echo "Idle Time Detail: $(echo "$IDLE_CATEGORY" | tail -n 1)"
                CREATE_TIME_GMT530=$(convert_to_gmt530 "$CREATE_TIME")
                echo "Creation Time (GMT+5:30): $CREATE_TIME_GMT530"
            fi
        done
    fi
}

# Function to check Elastic IPs
check_elastic_ips() {
    echo ""
    echo "Fetching Elastic IP usage details..."
    echo "===================================="
    EIP_ALLOCATIONS=$(aws ec2 describe-addresses --query 'Addresses[].AllocationId' --output text --region "$REGION" --profile "$AWS_PROFILE")


    if [ -z "$EIP_ALLOCATIONS" ]; then
        echo "No unused Elastic IPs found in region $REGION."
    else
        for allocation_id in $EIP_ALLOCATIONS; do
            echo "Elastic Allocation ID: $allocation_id"
            EIP_NAME=$(get_eip_name "$allocation_id")
            echo "Elastic IP Name: $EIP_NAME"
            ALLOCATION_TIME=$(aws ec2 describe-addresses --allocation-ids "$allocation_id" --query 'Addresses[].AllocationTime' --output text --region "$REGION" --profile "$AWS_PROFILE")
            echo "Elastic IP Allocation Time: $ALLOCATION_TIME"

            if [ -n "$ALLOCATION_TIME" ]; then
                IDLE_CATEGORY=$(get_idle_time_category "$ALLOCATION_TIME")
                IDLE_DAYS=$(echo "$IDLE_CATEGORY" | cut -d' ' -f3)  # Extract the number of days from the category

                echo "Elastic IP Name: $EIP_NAME"
                echo "Allocation ID: $allocation_id"
                echo "Idle Time Category: $(echo "$IDLE_CATEGORY" | head -n 1)"
                echo "Idle Time Detail: $(echo "$IDLE_CATEGORY" | tail -n 1)"
                ALLOCATION_TIME_GMT530=$(convert_to_gmt530 "$ALLOCATION_TIME")
                echo "Allocation Time (GMT+5:30): $ALLOCATION_TIME_GMT530"
            fiHn
        done
    fi
}

# Main script execution
load_config
check_ec2_instances
check_amis
check_snapshots
check_ebs_volumes
check_elastic_ips
