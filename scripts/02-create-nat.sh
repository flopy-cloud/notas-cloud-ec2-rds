#!/bin/bash
set -e

echo "Buscando IDs de la VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=notas-vpc" --query 'Vpcs[0].VpcId' --output text)
PUBLIC_SUBNET_1=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=notas-public-1" --query 'Subnets[0].SubnetId' --output text)
PRIVATE_SUBNET_1=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=notas-private-1" --query 'Subnets[0].SubnetId' --output text)
PRIVATE_SUBNET_2=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=notas-private-2" --query 'Subnets[0].SubnetId' --output text)

echo "VPC_ID=$VPC_ID"
echo "PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1"
echo "PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1"
echo "PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2"

echo "Paso 1: Asignando Elastic IP para el NAT Gateway..."
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
echo "Elastic IP asignada: $EIP_ALLOC"

echo "Paso 2: Creando NAT Gateway en subnet pública..."
NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id "$PUBLIC_SUBNET_1" \
  --allocation-id "$EIP_ALLOC" \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=notas-nat}]' \
  --query 'NatGateway.NatGatewayId' --output text)
echo "NAT Gateway creado: $NAT_GW_ID (tarda unos minutos en estar disponible)"

echo "Esperando a que el NAT Gateway esté disponible..."
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_GW_ID"
echo "NAT Gateway disponible."

echo "Paso 3: Creando tabla de rutas privada..."
PRIVATE_RT=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=notas-private-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id "$PRIVATE_RT" \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_GW_ID"

aws ec2 associate-route-table --subnet-id "$PRIVATE_SUBNET_1" --route-table-id "$PRIVATE_RT"
aws ec2 associate-route-table --subnet-id "$PRIVATE_SUBNET_2" --route-table-id "$PRIVATE_RT"

echo ""
echo "===== RESUMEN ====="
echo "EIP_ALLOC=$EIP_ALLOC"
echo "NAT_GW_ID=$NAT_GW_ID"
echo "PRIVATE_RT=$PRIVATE_RT"
echo "===================="
echo "Guardá estos valores para el próximo paso (Security Groups)."