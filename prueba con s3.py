import boto3
import os
import time
from botocore.exceptions import ClientError

# 1. CONFIGURACIÓN
BUCKET_NAME = 'rrhh-obligatorio-web'
LOCAL_PATH = '/home/matiascasasco/python_obligatorio/Archivos_de_Pagina_Web'
S3_PREFIX = 'webapp/'  # Carpeta virtual
DB_NAME = 'rrhh-database'
DB_USERNAME = 'admin'
DB_PASSWORD = 'RrhhSegura2025!'
DB_DATABASE = 'rrhh'
APP_USER = 'admin'
APP_PASS = 'admin123'
IMAGE_ID = 'ami-0fa3fe0fa7920f68e'

ec2 = boto3.client('ec2')
rds = boto3.client('rds')
s3 = boto3.client('s3')

# 2. SUBIR ARCHIVOS DE LA WEB A S3
print("\nSubiendo archivos web a S3...")
if not os.path.isdir(LOCAL_PATH):
    print(f"La carpeta NO existe: {LOCAL_PATH}")
    exit(1)

try:
    s3.create_bucket(Bucket=BUCKET_NAME)
    print(f"✓ bucket creado: {BUCKET_NAME}")
except Exception as e:
    if "BucketAlreadyOwnedByYou" in str(e):
        print("ℹ bucket ya existe.")

for folder, subs, files in os.walk(LOCAL_PATH):
    for filename in files:
        local_file = os.path.join(folder, filename)
        s3_key = os.path.relpath(local_file, LOCAL_PATH).replace("\\", "/")
        s3_path = f"{S3_PREFIX}{s3_key}"
        print(f"Subiendo: {local_file} -> s3://{BUCKET_NAME}/{s3_path}")
        s3.upload_file(local_file, BUCKET_NAME, s3_path)
print("✓ Archivos web subidos a S3 correctamente.\n")

# 3. CREAR LOS SECURITY GROUPS
print("Creando Security Group para EC2...")
sg_web_name = 'rrhh-web-sg'
sg_web_id = None
try:
    response = ec2.create_security_group(
        GroupName=sg_web_name,
        Description='SG para servidor web RRHH'
    )
    sg_web_id = response['GroupId']
    ec2.authorize_security_group_ingress(
        GroupId=sg_web_id,
        IpPermissions=[
            {
                'IpProtocol': 'tcp',
                'FromPort': 80,
                'ToPort': 80,
                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
            }
        ]
    )
    print(f"✓ SG Web creado: {sg_web_id}")
except ClientError as e:
    if e.response['Error']['Code'] == 'InvalidGroup.Duplicate':
        sg_response = ec2.describe_security_groups(GroupNames=[sg_web_name])
        sg_web_id = sg_response['SecurityGroups'][0]['GroupId']
        print(f"ℹ SG Web ya existe: {sg_web_id}")

print("\nCreando Security Group para RDS...")
sg_db_name = 'rrhh-db-sg'
sg_db_id = None
try:
    response = ec2.create_security_group(
        GroupName=sg_db_name,
        Description='SG para base de datos RRHH'
    )
    sg_db_id = response['GroupId']
    ec2.authorize_security_group_ingress(
        GroupId=sg_db_id,
        IpPermissions=[
            {
                'IpProtocol': 'tcp',
                'FromPort': 3306,
                'ToPort': 3306,
                'UserIdGroupPairs': [{'GroupId': sg_web_id}]
            }
        ]
    )
    print(f"✓ SG DB creado: {sg_db_id}")
except ClientError as e:
    if e.response['Error']['Code'] == 'InvalidGroup.Duplicate':
        sg_response = ec2.describe_security_groups(GroupNames=[sg_db_name])
        sg_db_id = sg_response['SecurityGroups'][0]['GroupId']
        print(f"ℹ SG DB ya existe: {sg_db_id}")

# 4. CREAR RDS MYSQL
print("\nDesplegando base de datos RDS...")
try:
    rds.create_db_instance(
        DBInstanceIdentifier=DB_NAME,
        DBInstanceClass='db.t3.micro',
        Engine='mysql',
        MasterUsername=DB_USERNAME,
        MasterUserPassword=DB_PASSWORD,
        DBName=DB_DATABASE,
        AllocatedStorage=20,
        StorageType='gp2',
        StorageEncrypted=True,
        VpcSecurityGroupIds=[sg_db_id],
        BackupRetentionPeriod=7,
        PubliclyAccessible=False
    )
    print("✓ RDS creado: esperando disponibilidad...")
    waiter = rds.get_waiter('db_instance_available')
    waiter.wait(DBInstanceIdentifier=DB_NAME)
    print("✓ RDS disponible")
except ClientError as e:
    if e.response['Error']['Code'] == 'DBInstanceAlreadyExists':
        print(f"ℹ RDS ya existe: {DB_NAME}")

db_info = rds.describe_db_instances(DBInstanceIdentifier=DB_NAME)
db_endpoint = db_info['DBInstances'][0]['Endpoint']['Address']
print(f"✓ Endpoint RDS: {db_endpoint}")

# 5. CREAR INSTANCIA EC2 Y USERDATA
print("\nDesplegando EC2 con configuración completa...")
user_data = f'''#!/bin/bash
yum update -y
yum install -y httpd php php-cli php-fpm php-common php-mysqlnd mariadb105 awscli

systemctl enable --now httpd
systemctl enable --now php-fpm

echo '<FilesMatch \.php$>
  SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost/"
</FilesMatch>' | tee /etc/httpd/conf.d/php-fpm.conf

rm -rf /var/www/html/*
aws s3 sync s3://{BUCKET_NAME}/webapp/ /var/www/html/

if [ -f /var/www/html/init_db.sql ]; then
  cp /var/www/html/init_db.sql /var/www/
fi

if [ ! -f /var/www/.env ]; then
cat > /var/www/.env << 'EOT'
DB_HOST={db_endpoint}
DB_NAME={DB_DATABASE}
DB_USER={DB_USERNAME}
DB_PASS={DB_PASSWORD}
APP_USER={APP_USER}
APP_PASS={APP_PASS}
EOT
fi

chown apache:apache /var/www/.env
chmod 600 /var/www/.env

chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

if [ -f /var/www/init_db.sql ]; then
  mysql -h {db_endpoint} -u {DB_USERNAME} -p{DB_PASSWORD} {DB_DATABASE} < /var/www/init_db.sql
fi

systemctl restart httpd php-fpm
echo "WEB desplegada desde S3"
'''

response = ec2.run_instances(
    ImageId=IMAGE_ID,
    InstanceType='t2.micro',
    MinCount=1,
    MaxCount=1,
    IamInstanceProfile={'Name': 'LabInstanceProfile'},
    SecurityGroupIds=[sg_web_id],
    UserData=user_data,
    BlockDeviceMappings=[
        {'DeviceName': '/dev/xvda', 'Ebs': {'VolumeSize': 8, 'VolumeType': 'gp2', 'Encrypted': True}}
    ]
)
instance_id = response['Instances'][0]['InstanceId']
ec2.create_tags(
    Resources=[instance_id],
    Tags=[
        {'Key': 'Name', 'Value': 'app-rrhh'},
        {'Key': 'Application', 'Value': 'RRHH'},
        {'Key': 'DataClassification', 'Value': 'Confidential'}
    ]
)

print("\nObteniendo IP pública...")
time.sleep(15)
instance_info = ec2.describe_instances(InstanceIds=[instance_id])
public_ip = instance_info['Reservations'][0]['Instances'][0].get('PublicIpAddress')

print("====================================")
print(" CHECKLIST DE VALIDACIÓN FINAL:")
print(f"- Archivos web subidos a S3 bajo webapp/: OK")
print(f"- Instancia RDS MySQL creada: OK")
print(f"- Endpoint RDS: {db_endpoint}")
print(f"- Security Groups web/db configurados: OK")
print(f"- EC2 creada y configurada con UserData: OK")
print(f"- IP pública para acceso web: {public_ip}\n")
print(f"Acceso web: http://{public_ip}")
print("====================================")
