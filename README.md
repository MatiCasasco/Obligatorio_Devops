# Obligatorio Programación para DevOps 2025

## Descripción del Proyecto
Este proyecto forma parte del curso Programación para DevOps y tiene como objetivo automatizar tareas para el equipo DevOps.   
Incluye dos componentes principales:

1. Script en Bash para la creación masiva de usuarios en Linux.
2. Script en Python para el despliegue seguro de la aplicación de Recursos Humanos, que maneja información sensible.

## Requisitos / Dependencias
- Sistema Operativo: Linux (distribución basada en Debian o similar).
- Permisos: Ejecución con privilegios de administrador para la creación de usuarios, preferentemente utilizar usuario root.
- Dependencias Bash:
  - useradd, passwd
- Dependencias Python:
  - Python 3.x
  - Librerías: boto3, paramiko (si aplica para despliegue en AWS)
- Git: Repositorio con control de versiones (commits y ramas).

## Modo de Uso

### Ejercicio 1 – Script en Bash
Archivos: crea_usuarios.sh  /  usuario_lista.txt

Sintaxis:
```bash
./crea_usuarios.sh [-i] [-c contraseña] usuario_lista.txt
```

Parámetros:
- -i → Muestra información detallada del resultado de la creación.
- -c → Define una contraseña para todos los usuarios.
- archivo_usuarios → Archivo con la lista de usuarios a crear.

Formato del archivo de usuarios:
```
usuario:comentario:/home/directorio:SI:/bin/bash
```

Ejemplo de ejecución:
```bash
./crea_usuarios.sh -i -c "123456" usuario_lista.txt
```

Salida esperada:
```
Usuario pepe creado con éxito con datos indicados:
Comentario: Este es mi amigo pepe
Dir home: /home/jose
Asegurado existencia de directorio home: SI
Shell por defecto: /bin/bash
Se han creado 2 usuarios con éxito.
```

### Ejercicio 2 – Script en Python
Archivo: deploy_rrhh.py

Descripción:
Automatiza el despliegue seguro de la aplicación de RRHH, asegurando la protección de datos sensibles (nombres, emails, salarios).

Ejemplo de ejecución:
```bash
python3 deploy_rrhh.py
```

Medidas de seguridad implementadas:
- Uso de credenciales seguras.
- Configuración de permisos mínimos.
- Logs trazables para auditoría.

## Estructura del Repositorio
```
├── ejercicio_bash
  ├── crea_usuarios.sh
  ├── usuario_lista.txt
├── ejercicio_python
  ├── deploy_rrhh.py
├── README.md
├── LICENSE
```

## Autores
- Mariana Varietti – 288481
- Matias Casasco – 
