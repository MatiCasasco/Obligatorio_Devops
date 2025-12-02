# Obligatorio Programación para DevOps 2025

## Situación del Obligatorio
El Banco Riendo está en proceso de adoptar un modelo de nube híbrida para cumplir con los requerimientos del negocio de forma acelerada. 
Para ello, el equipo de DevOps delega las siguientes tareas:

1. Crear un script en Bash que permita la creación masiva de usuarios a partir de un archivo, definiendo shell por defecto, directorio home, comentario y opción para crear el directorio home si no existe.
2. Crear un script en Python que automatice el despliegue seguro de la aplicación de Recursos Humanos, que contiene información sensible como nombres, emails y salarios.

Todos los cambios deben ser trazables mediante un repositorio en GitHub y documentados en este README.

## Objetivos del Proyecto
- Automatizar la creación de usuarios en Linux mediante un script en Bash.
- Implementar un script en Python para el despliegue seguro de una aplicación crítica.
- Garantizar la seguridad y protección de datos sensibles.
- Mantener trazabilidad y buenas prácticas de control de versiones en GitHub.
- Documentar claramente el proyecto para facilitar su uso y mantenimiento.

## Descripción del Proyecto
Este proyecto forma parte del curso **Programación para DevOps** y tiene como objetivo automatizar tareas para el equipo DevOps.

Incluye dos componentes principales:
- **Script en Bash:** Automatiza la creación masiva de usuarios en sistemas Linux.
- **Script en Python:** Automatiza el despliegue seguro de una aplicación de RRHH en AWS.

## Requisitos / Dependencias
- Sistema Operativo: Linux (distribución basada en Debian o similar).
- Permisos: Ejecución con privilegios de administrador para la creación de usuarios, preferentemente utilizar usuario root.
- Dependencias Bash:
  - useradd, passwd
- Dependencias Python:
  - Python 3.x
  - Librerías: boto3, botocore
  - AWS CLI configurada con credenciales válidas

## Modo de Uso

### Ejercicio 1 – Script en Bash
Archivos: ej1_crea_usuarios.sh  /  archivo_con_los_usuarios_a_crear.txt

Sintaxis:
```bash
./ej1_crea_usuarios.sh -i -c "hola123" archivo_con_los_usuarios_a_crear.txt
```

**Parámetros:**
- `-i` → Muestra información detallada.
- `-c` → Define una contraseña común.
- `archivo_usuarios` → Archivo con la lista de usuarios.

Formato del archivo de usuarios:
```
usuario:comentario:/home/directorio:SI:/bin/bash
```

Ejemplo de ejecución:
```bash
./ej1_crea_usuarios.sh -i -c "123456" archivo_con_los_usuarios_a_crear.txt
```

**Salida esperada:**
```
Usuario pepe creado con éxito con datos indicados:
Comentario: Este es mi amigo pepe
Dir home: /home/jose
Asegurado existencia de directorio home: SI
Shell por defecto: /bin/bash
Se han creado 2 usuarios con éxito.
```

### Ejercicio 2 – Script en Python
Archivo: `deploy_rrhh.py`

Descripción:
Automatiza el despliegue seguro de la aplicación de RRHH, asegurando la protección de datos sensibles (nombres, emails, salarios).

**Ejemplo:**
```bash
python3 deploy_rrhh.py
```

## Estructura del Repositorio
```
├── bash_obligatorio/
│   ├── archivo_con_los_usuarios_a_crear.txt
│   └── ej1_crea_usuarios.sh
├── python_obligatorio/
│   ├── Archivos_de_Pagina_Web/
│   ├── password_app.txt
│   ├── password_db.txt
│   └── python_app.py
├── LICENSE
└── README.md
```

## Autores
- Mariana Varietti – 288481
- Matias Casasco – 278023
