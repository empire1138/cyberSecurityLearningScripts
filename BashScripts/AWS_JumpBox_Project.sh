#!/bin/bash

#error checking limits
error_limit=3
counted_errors=0

#Timer for counters and countdowns
60_countdown_timer=60
5_countdown_timer=5
temp_countdown_timer=0

# Error Exit
trap 'echo "An error occurred while running the script. Exiting..."; exit 1' ERR

# Retrieve the public IP address
public_ip=$(curl -s https://checkip.dyndns.org | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')

#listed required variable
#user_ip_public_address
#user_aws_access_key_id
#user_aws_secret_access_key
#user_aws_session_token
#profile_username

#Setting the profile name for the user to user
#read -p "Please Enter the profile name to be used in AWS CLI (default is acceptable):" profile_username

#Read and set the aws accress keys
read -p "Please Enter the AWS Access Key ID" user_aws_access_key_id
aws configure set aws_access_key_id $user_aws_access_key_id
read -p "Please Enter the AWS Seret Access Key" user_aws_secret_access_key
aws configure set aws_secret_access_key $user_aws_secret_access_key
read -p "Please Enter the AWS Session Token" user_aws_session_token
aws configure set aws_session_token $user_aws_session_token

#Getting the AWS ID account Number for later use
aws_account_ID=($(aws sts get-caller-identity --query 'Account' --output text))
echo "Your Account AWS ID: $aws_account_ID will be used for this script"

# user must enter in the region. Then it checks with the aws cli that the region is correct. if not user has three times to enter a corrcet region before error exit
while true; do
  read -p "Enter the region you want to launch the Kali EC2 instace: " region
  valid_regions=($(aws ec2 describe-regions --output text --query 'Regions[*].RegionName'))
  if echo "${valid_regions[@]}" | grep -q -w "$region"; then
    aws configure set region "$region"
    echo "The region $region was set"
    break
  else
    echo "Invalid region. Please enter a valid region"
    counted_errors=$((counted_errors + 1))
    if [ $counted_errors -eq $error_limit ]; then
      echo "You have reached the invalid limit, the script will exit now"
      counted_errors=0
      exit 1
    fi
  fi
done

# Start of the selction menu
while true; do
  # Present menu options to the user
  echo "1. Make A Key Pair"
  echo "2. Name A Premade Key Pair"
  echo "4. Make a Security Group"
  echo "3. Add the a Premade Secutiy Group" # this will be the session token and other info
  echo "5. Set Secuity Group Ingress"
  echo "6. Launch a EC2 Instance"
  echo "7. Connect to EC2 Instance though ssh"
  echo "8. Delete EC2 Instance" # make sure to include a print out verifing the delection
  echo "9. Install Ngrok on EC2 Instance "
  echo "11. Install missing Pentesting tools"
  echo "12. Upgrading Kali to Kali large package tool set"
  echo "13. Exit"

  # Get user selection
  read -p "Enter your selection: " selection

  # Validate user input
  if [[ ! "$selection" =~ ^[0-13]$ ]]; then
    echo "Invalid selection. Please try again."
    continue
  fi

  # Process user selection
  case $selection in
  1) #Making a key pair and using it for the rest of the scipt
    #Create the key name what you want
    read -p "Enter Your Key name: " aws_key_name
    ssh_key="$aws_key_name.pem"
    # Generate AWS Keys and store in this local box
    echo "Generating key Pairs"
    aws ec2 create-key-pair --key-name $aws_key_name --query 'KeyMaterial' --output text 2>&1 | tee $ssh_key
    #Set read only access for key
    echo "Setting permissions"
    chmod 400 $ssh_key
    break
    ;;
  2) # Selecting a available Key Pair
    # user must enter A Key pair that is available in thatregion. Then it checks with the aws cli that the keypair is corret. if not user has three times to enter a corret keypair before error exit
    while true; do
      echo "The Available Key pairs for the region: $(aws ec2 describe-key-pairs --filters "Name=key-pair-state,Values=available" --query 'KeyPairs[*].KeyName' --output text | xargs)"
      read -p "Enter the A Key Pair Name: " aws_key_name
      vailid_aws_key_name=($(echo "The Available Key pairs for the region: "aws ec2 describe-key-pairs --filters "Name=key-pair-state,Values=available" --query 'KeyPairs[*].KeyName' --output text))
      if echo "${vaili_aws_key_name[@]}" | grep -q -w "$aws_key_name"; then
        echo "Selected Key Pair Name: $(aws_key_name)"
        break
      else
        echo "Invalid Key Pair. Please enter a valid Key Pair"
        counted_errors=$((counted_errors + 1))
        if [ $counted_errors -eq $error_limit ]; then
          echo "You have reached the invalid limit, the script will exit now"
          counted_errors=0
          exit 1
        fi
      fi
    done
    break
    ;;
  3) # Making a Secuity Group

    echo "Making Secuity Group"

    # Get the default VPC-ID
    default_vpc_id=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[*].VpcId' --output text)
    if [ -z "$default_vpc_id" ]; then
      echo "No default VPC ID found"
      read -p "Please enter a VPC ID for the Secuity Group Creaction" default_vpc_id
    else
      echo "Default VPC ID is: $default_vpc_id"
    fi

    #Enter Name for the secuity group
    echo -p "Please enter name for the secuity group" aws_kali_sec_group_name

    #making the secuity group
    aws ec2 create-security-group --group-name "$aws_kali_sec_group_name" --description "Security group for my Kali Linux EC2 instance" --vpc-id "$default_vpc_id" --region "$region"

    #confiming the making of the secuity group
    created_aws_kali_sec_group_name=$(aws ec2 describe-security-groups --region $region --filters "Name=owner-id,Values=$aws_account_ID" "Name=group-name,Values=$aws_kali_sec_group_name" --query 'SecurityGroups[*].GroupName' --output text)
    if [ -z "$created_aws_kali_sec_group_name" ]; then
      echo " Something went wrong while creating and selected the Security group: $aws_kali_sec_group_name"
      break
    else
      echo "A Security Group $aws_kali_sec_group_name was succesfully created"
    fi

    # Authorize SSH to the security group. Only computer Public IP Address on traffic on ssh. Public IP Address from https://checkip.dyndns.org
    echo "Making Ingress for Security Group $aws_kali_sec_group_name On Public Address $public_ip"
    aws ec2 authorize-security-group-ingress --group-name "$aws_kali_sec_group_name" --protocol tcp --port 22 --cidr $public_ip/32 --region "$region"
    break
    ;;
  4) # Selecting A Premade Secuity group
    while true; do
      echo "The Available Secuity group for the region and AWS Account ID: $(aws ec2 describe-security-groups --region $region --filters "Name=owner-id,Values=$aws_account_ID" --query 'SecurityGroups[*].GroupName' --output text)"
      read -p "Enter a Secuity Group Name: " aws_kali_sec_group_name
      vailid_aws_kali_sec_group_name=($(echo aws ec2 describe-security-groups --region $region --filters "Name=owner-id,Values=$aws_account_ID" --query 'SecurityGroups[*].GroupName' --output text))
      if echo "${vailid_aws_kali_sec_group_name[@]}" | grep -q -w "$aws_kali_sec_group_name"; then
        echo "Selected Secuity Group Name: $aws_kali_sec_group_name"
        # Authorize SSH to the security group. Only computer Public IP Address on traffic on ssh. Public IP Address from https://checkip.dyndns.org
        echo "Making Ingress for Security Group $aws_kali_sec_group_name On Public Address $public_ip for ssh traffic"
        aws ec2 authorize-security-group-ingress --group-name "$aws_kali_sec_group_name" --protocol tcp --port 22 --cidr $public_ip/32 --region "$region"
        break
      else
        echo "Invalid Secuity group. Please enter a valid Secuity group"
        counted_errors=$((counted_errors + 1))
        if [ $counted_errors -eq $error_limit ]; then
          echo "You have reached the invalid limit, the script will exit now"
          counted_errors=0
          exit 1
        fi
      fi
    done

    break
    ;;
  5)
    # Perform action for option
    ;;
  6)
    # Perform action for option
    ;;
  7)
    # Perform action for option
    ;;
  8)
    # Perform action for option
    ;;
  9)
    # Perform action for option
    ;;
  10)
    # Perform action for option
    ;;
  11)
    # Perform action for option
    ;;
  12)
    # Perform action for option
    ;;
  13)
    # Exit the program
    exit
    ;;
  esac
done
