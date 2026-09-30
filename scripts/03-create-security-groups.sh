#!/bin/bash
set -e

MY_IP="190.193.22.242/32"

echo "Buscando VPC_ID..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=notas-vpc" --query 'Vpcs[0].VpcId' --output text)
echo "VPC_ID=$VPC_ID"

echo "Paso 1: Creando Security Group para EC2..."
EC2_SG_ID=$(aws ec2 create-security-group \
  --group-name notas-ec2-sg \
  --description "SG para EC2 - SSH restringido y HTTP publico" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$EC2_SG_ID" \
  --protocol tcp --port 22 --cidr "$MY_IP"

aws ec2 authorize-security-group-ingress \
  --group-id "$EC2_SG_ID" \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

echo "EC2 SG creado: $EC2_SG_ID"

echo "Paso 2: Creando Security Group para RDS..."
RDS_SG_ID=$(aws ec2 create-security-group \
  --group-name notas-rds-sg \
  --description "SG para RDS - solo acceso desde EC2" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$RDS_SG_ID" \
  --protocol tcp --port 5432 --source-group "$EC2_SG_ID"

echo "RDS SG creado: $RDS_SG_ID"

echo ""
echo "===== RESUMEN ====="
echo "EC2_SG_ID=$EC2_SG_ID"
echo "RDS_SG_ID=$RDS_SG_ID"
echo "===================="
echo "Guardá estos valores para el próximo paso (RDS)."