#!/bin/bash
set -e

REGION="us-east-1"
AZ1="us-east-1a"
AZ2="us-east-1b"
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_1_CIDR="10.0.1.0/24"
PUBLIC_SUBNET_2_CIDR="10.0.2.0/24"
PRIVATE_SUBNET_1_CIDR="10.0.11.0/24"
PRIVATE_SUBNET_2_CIDR="10.0.12.0/24"

echo "Creando VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=notas-vpc}]' \
  --query 'Vpc.VpcId' --output text)
echo "VPC creada: $VPC_ID"

echo "Habilitando DNS hostnames..."
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames

echo "Creando subnets públicas..."
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" --cidr-block "$PUBLIC_SUBNET_1_CIDR" \
  --availability-zone "$AZ1" \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=notas-public-1}]' \
  --query 'Subnet.SubnetId' --output text)

PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" --cidr-block "$PUBLIC_SUBNET_2_CIDR" \
  --availability-zone "$AZ2" \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=notas-public-2}]' \
  --query 'Subnet.SubnetId' --output text)

echo "Creando subnets privadas..."
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" --cidr-block "$PRIVATE_SUBNET_1_CIDR" \
  --availability-zone "$AZ1" \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=notas-private-1}]' \
  --query 'Subnet.SubnetId' --output text)

PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" --cidr-block "$PRIVATE_SUBNET_2_CIDR" \
  --availability-zone "$AZ2" \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=notas-private-2}]' \
  --query 'Subnet.SubnetId' --output text)

echo "Creando Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=notas-igw}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"

echo "Creando tabla de rutas pública..."
PUBLIC_RT=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=notas-public-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id "$PUBLIC_RT" \
  --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"

aws ec2 associate-route-table --subnet-id "$PUBLIC_SUBNET_1" --route-table-id "$PUBLIC_RT"
aws ec2 associate-route-table --subnet-id "$PUBLIC_SUBNET_2" --route-table-id "$PUBLIC_RT"

echo "Habilitando auto-assign public IP en subnets públicas..."
aws ec2 modify-subnet-attribute --subnet-id "$PUBLIC_SUBNET_1" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$PUBLIC_SUBNET_2" --map-public-ip-on-launch

echo ""
echo "===== RESUMEN ====="
echo "VPC_ID=$VPC_ID"
echo "PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1"
echo "PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2"
echo "PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1"
echo "PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2"
echo "IGW_ID=$IGW_ID"
echo "PUBLIC_RT=$PUBLIC_RT"
echo "===================="
echo "Guardá estos valores, los vamos a necesitar en el próximo paso (NAT Gateway)."