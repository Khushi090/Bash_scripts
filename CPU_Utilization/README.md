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

