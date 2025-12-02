import boto3
import os
import time
from botocore.exceptions import ClientError

# ===================================================================================
# 1.                            CONFIGURACIÓN INICIAL
# ===================================================================================

NOMBRE_BUCKET = 'rrhh-obligatorio-web'
RUTA_LOCAL = './Archivos_de_Pagina_Web'
PREFIJO_S3 = 'webapp/'
ID_INSTANCIA_BD = 'rrhhapp'

# Credenciales de la base de datos (usuario y contraseña leída de archivo)
USUARIO_BD = 'admin'
CONTRASENA_BD = open("./password_db.txt", "r").read().strip()
NOMBRE_BD = 'demo_db'

# Credenciales de la aplicación (usuario fijo, contraseña desde archivo)
USUARIO_APP = 'admin'
CONTRASENA_APP = open("./password_app.txt", "r").read().strip()

# AMI que se usará para la instancia EC2
ID_IMAGEN = 'ami-0fa3fe0fa7920f68e'

# Clientes de AWS (EC2, RDS y S3) usando credenciales/configuración del entorno
cliente_ec2 = boto3.client('ec2')
cliente_rds = boto3.client('rds')
cliente_s3 = boto3.client('s3')

# ===================================================================================
# 2.                            SUBIR ARCHIVOS WEB A S3
# ===================================================================================

print("\nSubiendo archivos web a S3...")
print("========================================")

# Verificar que la carpeta local existe
if not os.path.isdir(RUTA_LOCAL):
    print(f"La carpeta NO existe: {RUTA_LOCAL}")
    exit(1)

# Crear el bucket S3 (si no existe ya)
try:
    cliente_s3.create_bucket(Bucket=NOMBRE_BUCKET)
    print(f"\nBucket creado: {NOMBRE_BUCKET}")
    print("======================================")
except Exception as e:
    # Si el bucket ya existe en tu cuenta, continuar
    if "BucketAlreadyOwnedByYou" in str(e):
        print("\n Bucket ya existe.")

# Recorrer recursivamente la carpeta local y subir todos los archivos al bucket
for carpeta, subcarpetas, archivos in os.walk(RUTA_LOCAL):                       # Recorrer recursivamente la carpeta base
    for nombre_archivo in archivos:                                            # Iterar sobre cada archivo en la carpeta actual
        ruta_local_archivo = os.path.join(carpeta, nombre_archivo)             # Obtener la ruta completa local del archivo
        clave_s3 = os.path.relpath(ruta_local_archivo, RUTA_LOCAL).replace("\\", "/")  # Ruta relativa normalizada para S3
        ruta_s3 = f"{PREFIJO_S3}{clave_s3}"                                   # Construir clave completa dentro del bucket S3
        print(f"Subiendo: {ruta_local_archivo} -> s3://{NOMBRE_BUCKET}/{ruta_s3}")   # Mostrar progreso de subida
        cliente_s3.upload_file(ruta_local_archivo, NOMBRE_BUCKET, ruta_s3)     # Subir archivo a S3 con clave definida


print("===============================================")
print("\n Archivos web subidos a S3 correctamente.\n")

# ===================================================================================
# 3.                            CREAR SECURITY GROUPS
# ===================================================================================

# --- SG para servidor web (HTTP 80 abierto a Internet) ---
NOMBRE_SG_WEB = 'rrhh-web-sg'
ID_SG_WEB = None

try:
    # Crear SG para la capa web
    respuesta = cliente_ec2.create_security_group(
        GroupName=NOMBRE_SG_WEB,
        Description='SG para servidor web RRHH'
    )
    ID_SG_WEB = respuesta['GroupId']

    # Permitir tráfico HTTP (80) desde cualquier IP
    cliente_ec2.authorize_security_group_ingress(
        GroupId=ID_SG_WEB,
        IpPermissions=[
            {
                'IpProtocol': 'tcp',
                'FromPort': 80,
                'ToPort': 80,
                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
            }
        ]
    )
    print(f"\nSecurity Group web '{NOMBRE_SG_WEB}' creado con ID: {ID_SG_WEB}")

except ClientError as e:
    # Si el SG ya existe, obtener su ID
    if e.response['Error']['Code'] == 'InvalidGroup.Duplicate':
        sg_respuesta = cliente_ec2.describe_security_groups(GroupNames=[NOMBRE_SG_WEB])
        ID_SG_WEB = sg_respuesta['SecurityGroups'][0]['GroupId']
        print(f"\n Security Group web '{NOMBRE_SG_WEB}' ya existe con ID: {ID_SG_WEB}")



# --- SG para base de datos (MySQL 3306 solo desde SG web) ---
NOMBRE_SG_BD = 'rrhh-db-sg'
ID_SG_BD = None

try:
    # Crear SG para la capa de base de datos
    respuesta = cliente_ec2.create_security_group(
        GroupName=NOMBRE_SG_BD,
        Description='SG para base de datos RRHH'
    )
    ID_SG_BD = respuesta['GroupId']

    # Permitir tráfico MySQL (3306) solo desde el SG de la web
    cliente_ec2.authorize_security_group_ingress(
        GroupId=ID_SG_BD,
        IpPermissions=[
            {
                'IpProtocol': 'tcp',
                'FromPort': 3306,
                'ToPort': 3306,
                'UserIdGroupPairs': [{'GroupId': ID_SG_WEB}]
            }
        ]
    )
    print(f"\nSecurity Group BD '{NOMBRE_SG_BD}' creado con ID: {ID_SG_BD}")

except ClientError as e:
    # Si el SG ya existe, obtener su ID
    if e.response['Error']['Code'] == 'InvalidGroup.Duplicate':
        sg_respuesta = cliente_ec2.describe_security_groups(GroupNames=[NOMBRE_SG_BD])   # Consultar detalles del Security Group existente por su nombre
        ID_SG_BD = sg_respuesta['SecurityGroups'][0]['GroupId']  # Extraer el ID del primer Security Group encontrado con ese nombre
        print(f"\nSG BD ya existe: {ID_SG_BD}")

# ===================================================================================
# 4.                            CREAR INSTANCIA RDS MYSQL
# ===================================================================================

try:
    # Crear la instancia RDS MySQL con las credenciales y SG configurados
    cliente_rds.create_db_instance(
        DBInstanceIdentifier=ID_INSTANCIA_BD,   
        DBInstanceClass='db.t3.micro',          
        Engine='mysql',                         # Motor de base de datos a usar (MySQL en este caso)
        MasterUsername=USUARIO_BD,             
        MasterUserPassword=CONTRASENA_BD,       
        DBName=NOMBRE_BD,                       
        AllocatedStorage=20,                    # Tamaño del disco de la DB en GB (almacenamiento EBS)
        StorageType='gp2',                      # Tipo de almacenamiento (SSD de uso general gp2)
        StorageEncrypted=True,                  # Indica que el almacenamiento estará cifrado en reposo
        VpcSecurityGroupIds=[ID_SG_BD],         
        BackupRetentionPeriod=7,                # Cuántos días conservar los backups automáticos
        PubliclyAccessible=False                # False = la DB no tiene IP pública, solo accesible dentro de la VPC
    )


    print("\nRDS creado: esperando disponibilidad...")

    # Esperar hasta que la instancia esté en estado 'available'
    waiter = cliente_rds.get_waiter('db_instance_available') # Crear un waiter para esperar a que la instancia RDS esté disponible
    waiter.wait(DBInstanceIdentifier=ID_INSTANCIA_BD) # Bloquear la ejecución hasta que la instancia esté en estado 'available'
    print("\nRDS disponible y listo para usar.")

except ClientError as e:
    if e.response['Error']['Code'] == 'DBInstanceAlreadyExists':
        print(f"\n RDS ya existe: {ID_INSTANCIA_BD}")
    else:
        print("Error creando RDS:", e)
        raise

# Obtener la información de la instancia RDS (endpoint para conectarse)
info_bd = cliente_rds.describe_db_instances(DBInstanceIdentifier=ID_INSTANCIA_BD)
ENDPOINT_BD = info_bd['DBInstances'][0]['Endpoint']['Address'] #Guarda en una variable la direccion de la base de datos.

# ===================================================================================
# 5.                           CREAR INSTANCIA EC2 + USER DATA
# ===================================================================================

# Script de inicialización (user data) que se ejecuta al arrancar la EC2
# Instala Apache + PHP, sincroniza la web desde S3, crea el .env, inicializa la BD, etc.
datos_usuario = f'''#!/bin/bash
yum update -y
yum install -y httpd php php-cli php-fpm php-common php-mysqlnd mariadb105 awscli

# Habilitar y arrancar servicios web y PHP-FPM
systemctl enable --now httpd
systemctl enable --now php-fpm

# Configurar Apache para usar php-fpm a través de socket Unix
echo '<FilesMatch \\\\.php$>
  SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost/"
</FilesMatch>' | tee /etc/httpd/conf.d/php-fpm.conf

# Limpiar carpeta web y descargar versión actual desde S3
rm -rf /var/www/html/*
aws s3 sync s3://{NOMBRE_BUCKET}/webapp/ /var/www/html/

# Copiar script de inicialización de base de datos si existe
if [ -f /var/www/html/init_db.sql ]; then
  cp /var/www/html/init_db.sql /var/www/
fi

# Crear archivo .env con credenciales y configuración solo si no existe
if [ ! -f /var/www/.env ]; then
cat > /var/www/.env << 'EOT'
DB_HOST={ENDPOINT_BD}
DB_NAME={NOMBRE_BD}
DB_USER={USUARIO_BD}
DB_PASS={CONTRASENA_BD}
APP_USER={USUARIO_APP}
APP_PASS={CONTRASENA_APP}
EOT
fi

# Proteger .env y dar permisos adecuados a la carpeta web
chown apache:apache /var/www/.env
chmod 600 /var/www/.env

chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Ejecutar script SQL de inicialización contra la base de datos RDS
if [ -f /var/www/init_db.sql ]; then
  mysql -h {ENDPOINT_BD} -u {USUARIO_BD} -p{CONTRASENA_BD} {NOMBRE_BD} < /var/www/init_db.sql
fi

# Reiniciar servicios para aplicar todos los cambios
systemctl restart httpd php-fpm
'''

# Lanzar la instancia EC2 con el user-data anterior
respuesta_ec2 = cliente_ec2.run_instances(
    ImageId=ID_IMAGEN,
    InstanceType='t2.micro',
    MinCount=1,
    MaxCount=1,
    IamInstanceProfile={'Name': 'LabInstanceProfile'},
    SecurityGroupIds=[ID_SG_WEB],
    UserData=datos_usuario
)

# ID de la instancia EC2 recién creada
ID_INSTANCIA = respuesta_ec2['Instances'][0]['InstanceId']
print(f"\nInstancia EC2 creada con ID: {ID_INSTANCIA}")
# Etiquetas para identificar la instancia y la clasificación de datos
cliente_ec2.create_tags(
    Resources=[ID_INSTANCIA],
    Tags=[
        {'Key': 'Name', 'Value': 'app-rrhh'},
        {'Key': 'Application', 'Value': 'RRHH'},
        {'Key': 'DataClassification', 'Value': 'Confidential'}
    ]
)

# ===================================================================================
# 6.                       OBTENER IP PÚBLICA Y MOSTRAR URL
# ===================================================================================

print("\nObteniendo IP pública...")
# Esperar unos segundos a que AWS asigne la IP pública
time.sleep(15)

# Consultar detalles de la instancia para obtener la IP pública
info_instancia = cliente_ec2.describe_instances(InstanceIds=[ID_INSTANCIA])  # Solicita información detallada de la instancia EC2 con el ID dado
IP_PUBLICA = info_instancia['Reservations'][0]['Instances'][0].get('PublicIpAddress')  # Extrae la dirección IP pública de la instancia si existe


# Mostrar URL de acceso a la aplicación web
print(f"Acceso web: http://{IP_PUBLICA}/login.php")
print("============================================")
