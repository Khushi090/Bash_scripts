# AWS EC2 CPU Utilization Monitoring Script

This script is designed to monitor the CPU utilization of AWS EC2 instances over a specified date range. It can handle multiple AWS profiles and regions as specified in a configuration file. The script calculates the total average CPU utilization for each instance and outputs the results.

## Prerequisites

Before running the script, ensure you have the following prerequisites set up:

1. **AWS CLI**: The script relies on the AWS Command Line Interface (CLI) to interact with AWS services. If you don't have the AWS CLI installed, follow these steps:
   - Install the AWS CLI: [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
   - Configure the AWS CLI with your credentials:
     ```bash
     aws configure
     ```
     This will prompt you to enter your AWS Access Key ID, Secret Access Key, Default region name, and Default output format.
   - To configure additional profiles, use the following command:
     ```bash
     aws configure --profile <profile_name>
     ```
     Replace `<profile_name>` with the name of your profile. This will allow you to set up multiple profiles.

2. **Bash**: Ensure you are running the script in a Bash environment.

## Configuration

Create a [config.properties](https://github.com/Khushi090/Bash_scripts/blob/main/CPU_Utilization/config.properties) file in the same directory as the script with the following content:

```properties
AWS_PROFILE=("default" "chanderkant")
REGION=("us-east-1" "us-west-2" "eu-west-1")
```

## [Script Explanation](https://github.com/Khushi090/Bash_scripts/blob/main/CPU_Utilization/cpu.sh)

The script consists of the following parts:

### Configuration File Check: This part checks for the existence of the config.properties file and sources it to load AWS profiles and regions.

<details>
<summary><code>Configuration File Check</code></summary>
<br>
   
 ```shell  
   CONFIG_FILE="config.properties"

if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  echo "Configuration file not found!"
  exit 1
fi
```
<br>
</details>

### Date Input: Prompts the user to enter the start and end dates for monitoring CPU utilization.

<details>
<summary><code>Date Input</code></summary>
<br>
   
 ```shell  
read -p "Enter the start date (YYYY-MM-DD): " START_DATE
read -p "Enter the end date (YYYY-MM-DD): " END_DATE

if [ -z "$START_DATE" ] || [ -z "$END_DATE" ]; then
  echo "Start date and end date are required."
  exit 1
fi

```
<br>
</details>

### AWS Profile and Region Handling: Ensures the AWS profiles and regions are loaded as arrays.

<details>
<summary><code>AWS Profile and Region Handling</code></summary>
<br>
   
 ```shell  
AWS_PROFILES=("${AWS_PROFILE[@]}")
REGIONS=("${REGION[@]}")
```
<br>
</details>

### Iterate Through Profiles and Regions: This part iterates through each profile and region to check for AWS credentials.

<details>
<summary><code>Iterate Through Profiles and Regions</code></summary>
<br>
   
 ```shell  
for PROFILE in "${AWS_PROFILES[@]}"; do
  export AWS_PROFILE="$PROFILE"
  
  AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id --profile $AWS_PROFILE)
  AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key --profile $AWS_PROFILE)
  
  if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Missing required AWS credentials in profile $AWS_PROFILE."
    continue
  fi

```
<br>
</details>

### Retrieve CPU Utilization: This function retrieves the CPU utilization metrics for each instance.

<details>
<summary><code>Retrieve CPU Utilization</code></summary>
<br>
   
 ```shell  
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

```
<br>
</details>


### Retrieve Instance Info: This function retrieves the instance name and tags.

<details>
<summary><code>Retrieve Instance Info</code></summary>
<br>
   
 ```shell  
get_instance_info() {
  INSTANCE_ID=$1
  INSTANCE_NAME=$(aws ec2 describe-tags --profile $AWS_PROFILE --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query 'Tags[0].Value' --output text)
  echo "Instance Name :- $INSTANCE_NAME"
  echo "Tags:"
  echo "====="
  aws ec2 describe-tags --profile $AWS_PROFILE --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" --query 'Tags[].[Key,Value]' --output text
}

```
<br>
</details>

### Calculate and Display Total Average CPU Utilization: This part calculates the total average CPU utilization for each instance and displays it.

<details>
<summary><code>Calculate and Display Total Average CPU Utilization</code></summary>
<br>
   
 ```shell  
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

```
<br>
</details>

## How to Run the Script 

Ensure you have the config.properties file in the same directory as the script.

## Make the script executable:

```shell 
chmod +x script_name.sh
```

## Run the script:

```shell
./cpu.sh
```

## Example Output

```shell 
Enter the start date (YYYY-MM-DD): 2024-07-11
Enter the end date (YYYY-MM-DD): 2024-07-13

*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Using profile: default
Using region: us-east-1
*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Debug: AWS_PROFILE=default, REGION=us-east-1
Debug: Instance IDs found in profile default and region us-east-1: i-0fe11080f7a385a49

Instance ID   :- i-0fe11080f7a385a49
Instance Name :- docker django
Tags:
=====
Name    docker django
Total average CPU utilization for instance i-0fe11080f7a385a49 (From 2024-07-11 to 2024-07-13): 1.44

*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Using profile: default
Using region: us-west-2
*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Debug: AWS_PROFILE=default, REGION=us-west-2
Debug: Instance IDs found in profile default and region us-west-2:
No instances found in profile default and region us-west-2.

*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Using profile: default
Using region: eu-west-1
*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Debug: AWS_PROFILE=default, REGION=eu-west-1
Debug: Instance IDs found in profile default and region eu-west-1:
No instances found in profile default and region eu-west-1.

*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Using profile: chanderkant
Using region: us-east-1
*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Debug: AWS_PROFILE=chanderkant, REGION=us-east-1
Debug: Instance IDs found in profile chanderkant and region us-east-1: i-09b650c7472949d92 i-070c88cf1bd772eca i-0f14a14f3346ee31c i-057c993bdd6f87e18

Instance ID   :- i-09b650c7472949d92
Instance Name :- testing
Tags:
=====
Name    testing
Total average CPU utilization for instance i-09b650c7472949d92 (From 2024-07-11 to 2024-07-13): 10.71

Instance ID   :- i-070c88cf1bd772eca
Instance Name :- test_01
Tags:
=====
Name    test_01
Total average CPU utilization for instance i-070c88cf1bd772eca (From 2024-07-11 to 2024-07-13): 1.74

Instance ID   :- i-0f14a14f3346ee31c
Instance Name :- test_02
Tags:
=====
Name    test_02
Total average CPU utilization for instance i-0f14a14f3346ee31c (From 2024-07-11 to 2024-07-13): .13

Instance ID   :- i-057c993bdd6f87e18
Instance Name :- test_03
Tags:
=====
Name    test_03
Total average CPU utilization for instance i-057c993bdd6f87e18 (From 2024-07-11 to 2024-07-13): 1.75

*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Using profile: chanderkant
Using region: us-west-2
*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Debug: AWS_PROFILE=chanderkant, REGION=us-west-2
Debug: Instance IDs found in profile chanderkant and region us-west-2:
No instances found in profile chanderkant and region us-west-2.

*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Using profile: chanderkant
Using region: eu-west-1
*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Debug: AWS_PROFILE=chanderkant, REGION=eu-west-1
Debug: Instance IDs found in profile chanderkant and region eu-west-1:
No instances found in profile chanderkant and region eu-west-1.
```

![image](https://github.com/user-attachments/assets/660d9b88-b6b5-46a9-afd9-cb50aef5c805)

# Contact Information
| Name            | Email Address                        |
|-----------------|--------------------------------------|
| Khushi Malhotra  | khushimalhotra0209@gmail.com |
