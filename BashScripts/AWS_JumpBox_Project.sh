#!/bin/bash

echo -e "\e  
    ___ _       _______    _____ __________  ________  ______   ____  ____  ____      ____________________
   /   | |     / / ___/   / ___// ____/ __ \/  _/ __ \/_  __/  / __ \/ __ \/ __ \    / / ____/ ____/_  __/
  / /| | | /| / /\__ \    \__ \/ /   / /_/ // // /_/ / / /    / /_/ / /_/ / / / /_  / / __/ / /     / /   
 / ___ | |/ |/ /___/ /   ___/ / /___/ _, _// // ____/ / /    / ____/ _, _/ /_/ / /_/ / /___/ /___  / /    
/_/  |_|__/|__//____/   /____/\____/_/ |_/___/_/     /_/    /_/   /_/ |_|\____/\____/_____/\____/ /_/   "

#error checking limits
error_limit=3
counted_errors=0

#Timer for counters and countdowns
sixty_countdown_timer=60
five_countdown_timer=5
temp_countdown_timer=0

# Error Exit
#trap 'echo "An error occurred while running the script. Exiting..."; exit 1' ERR

#Generate a random id. Without a uniuqe ID the run instance command later in the code would grab from the top of the list and not the just created instace.
uid=$RANDOM
echo "For Creating EC2 instance in AWS a uniuqe ID can help with the tracking and order. UID: $uid "

# Retrieve the public IP address
public_ip=$(curl -s http://checkip.dyndns.org | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
echo "Your Public IP Address is $public_ip and will be used this this script"

#Set the type of instance you would like. Here, I am specifying a T2 medium instance.
instance_type="t2.medium"

#listed required variable
#user_ip_public_address
#user_aws_access_key_id
#user_aws_secret_access_key
#user_aws_session_token
#profile_username
region="us-west-1"

# Create an optional tag.
tag="thatnothing"

#Setting the profile name for the user to user
#read -p "Please Enter the profile name to be used in AWS CLI (default is acceptable):" profile_username

#this will check if there is useable keys and sessions tokens already Read and set the aws accress keys
echo "Checking account info "
aws sts get-caller-identity &>/dev/null
if [[ $? -ne 0 ]]; then
  echo "No current info found Please enter the following infomation"
  read -p "Please Enter the AWS Access Key ID: " user_aws_access_key_id
  aws configure set aws_access_key_id $user_aws_access_key_id
  read -p "Please Enter the AWS Seret Access Key: " user_aws_secret_access_key
  aws configure set aws_secret_access_key $user_aws_secret_access_key
  read -p "Please Enter the AWS Session Token: " user_aws_session_token
  aws configure set aws_session_token $user_aws_session_token
fi

#Getting the AWS ID account Number for later use
aws_account_ID=($(aws sts get-caller-identity --query 'Account' --output text))
echo "Your Account AWS ID: $aws_account_ID will be used for this script"

# user must enter in the region. Then it checks with the aws cli that the region is correct. if not user has three times to enter a corret region before error exit
while true; do
  #print out the list of regions
  echo " Here is a list of the useable regions for aws. Please select one. The default region is us-west-1"
  aws ec2 describe-regions --output text --query 'Regions[*].RegionName' | xargs

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
  echo "3. Make a Security Group"
  echo "4. Add the a Premade Secutiy Group" # this will be the session token and other info
  echo "5. Launch a EC2 Instance"
  echo "6. Connect to EC2 Instance though ssh with pentesting tools install"
  echo "7. Connect to EC2 Instace though ssh. No pentesting tools"
  echo "8. Delete EC2 Instance" # make sure to include a print out verifing the delection
  echo "9. Exit"

  # Get user selection
  read -p "Enter your selection: " selection

  # Validate user input
  if [[ ! "$selection" =~ [1-9]$ ]]; then
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
    ;;
  2) # Selecting a available Key Pair
    # aws cli will list out the key pair names.User will enter the name.Then it checks with the aws cli that the keypair is corret. if not user has three times to enter a corret keypair before error exit
    while true; do
      echo "The Available Key pairs for the region: $(aws ec2 describe-key-pairs --key-names  --query 'KeyPairs[].KeyName' --output text)"
      read -p "Enter the A Key Pair Name: " aws_key_name
      valid_aws_key_name=($(aws ec2 describe-key-pairs --key-names  --query 'KeyPairs[].KeyName' --output text))
      if echo "${valid_aws_key_name[@]}" | grep -q -w "$aws_key_name"; then
        echo "Selected Key Pair Name: $aws_key_name"
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
    read -p "Please enter name for the secuity group: " aws_kali_sec_group_name

    #making the secuity group
    aws ec2 create-security-group --group-name $aws_kali_sec_group_name --description "Security group for my Kali Linux EC2 instance" --vpc-id $default_vpc_id --region $region

    #confiming the making of the secuity group
    created_aws_kali_sec_group_name=$(aws ec2 describe-security-groups --region $region --filters "Name=owner-id,Values=$aws_account_ID" "Name=group-name,Values=$aws_kali_sec_group_name" --query 'SecurityGroups[*].GroupName' --output text)
    if [ -z "$created_aws_kali_sec_group_name" ]; then
      echo " Something went wrong while creating and selected the Security group: $aws_kali_sec_group_name"
      break
    else
      echo "A Security Group $aws_kali_sec_group_name was succesfully created"
    fi

    # Authorize SSH to the security group. Only computer Public IP Address on traffic on ssh. Public IP Address from https://checkip.dyndns.org
    echo "Making Ingress for Security Group $aws_kali_sec_group_name On Public Address $public_ip for ssh traffic"
    aws ec2 authorize-security-group-ingress --group-name $aws_kali_sec_group_name --protocol tcp --port 22 --cidr $public_ip/32 --region $region
    ;;
  4) # Selecting A Premade Secuity group
    while true; do
      echo "The Available Secuity group for the region and AWS Account ID: $(aws ec2 describe-security-groups --region $region --filters "Name=owner-id,Values=$aws_account_ID" --query 'SecurityGroups[*].GroupName' --output text)"
      read -p "Enter a Secuity Group Name: " aws_kali_sec_group_name
      vailid_aws_kali_sec_group_name=($(aws ec2 describe-security-groups --region $region --filters "Name=owner-id,Values=$aws_account_ID" --query 'SecurityGroups[*].GroupName' --output text))
      if echo "${vailid_aws_kali_sec_group_name[@]}" | grep -q -w "$aws_kali_sec_group_name"; then
        echo "Selected Secuity Group Name: $aws_kali_sec_group_name"
        aws_kali_sec_group_ID=$(aws ec2 describe-security-groups --region $region --filters "Name=group-name,Values=$aws_kali_sec_group_name" --query 'SecurityGroups[*].GroupId' --output text)
        echo "security group id : $aws_kali_sec_group_ID"
        # Authorize SSH to the security group. Only computer Public IP Address on traffic on ssh. Public IP Address from https://checkip.dyndns.org
        #echo "Making Ingress for Security Group $aws_kali_sec_group_name On Public Address $public_ip for ssh traffic"
        #aws ec2 authorize-security-group-ingress --group-name "$aws_kali_sec_group_name" --protocol tcp --port 22 --cidr $public_ip/32 --region "$region"
        break
      else
        echo "Invalid Secuity group. Please enter a valid Secuity group"
        counted_errors=$((counted_errors + 1))
        if [ $counted_errors -eq $error_limit ]; then
          echo "You have reached the invalid limit, the script will exit now"
          counted_errors=0
          break
        fi
      fi
    done
    ;;
  5) # Launch the EC2 instance

    #Need to check that the other req fields aren't empty.
    if [ -z "$aws_key_name" ] || [ -z "$aws_kali_sec_group_name" ]; then
      echo "Something went wrong. Go back and do 1 or 2 and 3 or 4 options again"
      break
    else
      echo "The selected Security Group: $aws_kali_sec_group_name and Key pair:  $aws_key_name"
    fi

    #Grab the Kali AMI ID for the region. This will return the id for the ami kali based on the kali rolling linux.
    echo "Going to grab the Kali AMI ID for $region"
    ami_id=($(aws ec2 describe-images --region $region --owners aws-marketplace --filters Name=name,Values=kali-rolling* --query 'Images[*].{ID:ImageId}' --profile default --output json | jq -r '.[].ID'))
    if [ -z "$ami_id" ]; then
      echo " Something went wrong grabing the Kail Linux image ID for the $region region "
      break
    else
      echo "The AMI for kali linux is : $ami_id and has be succefully added to the script"
    fi

    #Instance is set as a goblal constance at the top for m2.medium. Change it up there if you want to different type
    echo "The instance type for this instance will be: $instance_type"
    echo "UID: $uid "

    #Launch the EC2 Instace #Confirm the EC2 Instace is running and Grab the instace Id
    # the First run instace made. Just keeping it here in case: aws ec2 run-instances --image-id "$ami_id" --instance-type "$instance_type" --key-name "$aws_key_name" --security-group-names "$aws_kali_sec_group_name" --region "$region"
    ec2_id=$(aws ec2 run-instances --image-id $ami_id --count 1 --instance-type $instance_type --key-name $aws_key_name --security-group-ids $aws_kali_sec_group_ID --region $region --associate-public-ip-address --tag-specifications "ResourceType=instance,Tags=[{Key=WatchTower,Value='$tag'},{Key=AutomatedID,Value='$uid'}]" | grep InstanceId | cut -d":" -f2 | cut -d'"' -f2)
    echo "EC2 ID : $ec2_id "

    #ec2 Id Check for empty
    while [ -z "$ec2_id" ]; do
      echo "Waiting for EC2 ID"
      ec2_id=$(aws ec2 describe-instances --filters "Name=tag:AutomatedID,Values=$uid" "Name=tag:WatchTower,Values=$tag" --query 'Reservations[].Instances[].InstanceId' --output text)
      sleep 1
    done

    #Adding a Delay to the code to wait for the public ip address
    echo "Starting Instance Check "
    while [ $(aws ec2 describe-instances --instance-ids $ec2_id --query 'Reservations[0].Instances[0].State.Name' --output text) != "running" ]; do
      if [ $(aws ec2 describe-instances --instance-ids $ec2_id --query 'Reservations[0].Instances[0].State.Name' --output text) != "pending" ]; then
        sleep 1
      else
        echo -e "Waiting for instance to start..."
        sleep 1
      fi
    done

    #Grab the EC2 Instace Public IP address. Could also change this to use the public DNS instead of the ip address.
    echo "EC2 Instance ID: $ec2_id"
    aws_public_ip=$(aws ec2 describe-instances --instance-ids $ec2_id --query 'Reservations[0].Instances[0].PublicIpAddress' | cut -d'"' -f2)
    echo -e "Aws Public IP: $aws_public_ip"
    ;;
  6) #Connect to EC2 instace though ssh. This will add a timer before connecting to ec2 on ssh.
    echo "Please wait while your instance is being powered on..We are trying to ssh into the EC2 instance"
    echo "Copy/paste the below command to acess your EC2 instance via SSH from this machine. You may need this later"
    echo ""
    echo "\033[0;31m ssh -i $ssh_key kali@$aws_public_ip\033[0m"

    temp_countdown_timer=${five_countdown_timer}
    while [[ ${temp_countdown_timer} -gt 0 ]]; do
      printf "\rYou have %2d second(s) remaining to hit Ctrl+C to cancel that operation!" ${temp_countdown_timer}
      sleep 1
      ((temp_countdown_timer--))
    done
    temp_countdown_timer=0 #resting the temp countdown time
    echo "Trying to connect to EC2 Kali instance at $aws_public_ip"
    # Need to add change to pipe in a new scipt into the ssh connection
    #ssh -i $ssh_key kali@$aws_public_ip
    sudo ssh -o "StrictHostKeyChecking no" -t -i $ssh_key kali@$aws_public_ip 'bash -s' <pentesting_setup.sh
    ;;
  7) #Connect to EC2 Instace though ssh. No pentesting tools
    echo "Please wait while your instance is being powered on..We are trying to ssh into the EC2 instance"
    echo "Copy/paste the below command to acess your EC2 instance via SSH from this machine. You may need this later"
    echo ""
    echo "\033[0;31m ssh -i $ssh_key kali@$aws_public_ip\033[0m"

    temp_countdown_timer=${five_countdown_timer}
    while [[ ${temp_countdown_timer} -gt 0 ]]; do
      printf "\rYou have %2d second(s) remaining to hit Ctrl+C to cancel that operation!" ${temp_countdown_timer}
      sleep 1
      ((temp_countdown_timer--))
    done
    temp_countdown_timer=0 #resting the temp countdown time
    echo "Trying to connect to EC2 Kali instance at $aws_public_ip"
    # Need to add change to pipe in a new scipt into the ssh connection
    ssh -i $ssh_key kali@$aws_public_ip
    ;;
  8) #Delete the ec2 instace
    # Confirm the ec2 instance is still up and running
    aws ec2 describe-instances --instance-ids $ec2_id --output json
    # Ask the user to confirm delection
    # Timer for delection
    # Delection
    aws ec2 terminate-instances --instance-ids $ec2_id
    ;;
  9)
    # Exit the program
    exit
    ;;
  esac
done



