#!/bin/bash

#make sure you add the aws_access_key_id aws_secret_access_key  aws_session_token to config file .aws/crentials 
#Or run the commands "aws configure set aws_access_key_id <access-key> --profile default"  "aws configure set aws_secret_access_key <secret-access-key> --profile default" "aws configure set aws_session_token <session-token> --profile default"
#Make sure the region is set for the aws cli. "aws configure list" will list the region. "aws configure set region us-west-1" will change to region to west-1


# Set the region and availability zone
region="us-west-1"
#az="us-west-1"

# Set the instance type and AMI ID
instance_type="t2.medium"
ami_id="<AMI ID>" # Kali Linux

# Set the key pair name. This Key pair needs to be made on the website for correct region 
key_pair_name="<Premade Key Name>"

# Set the security group name. A already made security group. Needs to be change to a group you make on the website. 
security_group_name="<PreMade Security Group Name>"

# Create the security group
#aws ec2 create-security-group --group-name "<Group Name>" --description "<descrip the group>" --vpc-id <VPC ID> --region "$region"

# Authorize SSH and HTTP access to the security group This will take all traffic on ssh and http. Doesn't block on ip address for ports 22 and 80
aws ec2 authorize-security-group-ingress \
    --group-name "$security_group_name" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region "$region"
aws ec2 authorize-security-group-ingress \
    --group-name "$security_group_name" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region "$region"

# Create the EC2 instance
aws ec2 run-instances \
    --image-id "$ami_id" \
    --instance-type "$instance_type" \
    --key-name "$key_pair_name" \
    --security-group-ids "$security_group_name" \
    --region "$region"
