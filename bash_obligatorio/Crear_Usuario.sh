#!/bin/bash

# ==========================
# 1. VARIABLES Y PARAMETROS
# ==========================

param_i=false          # Param -i: mostrar información detallada de los usuarios procesados
param_c=false          # Param -c: indicar que se debe asignar contraseña a los usuarios
password=""           # Contraseña que se usará si se pasa -c
archivo=""            # Nombre del archivo de entrada con los datos de usuarios
contador=0            # Contador de usuarios creados
modi=0                # Contador de usuarios modificados

# ==========================
# 2. FUNCIÓN AUXILIAR: mostrar_datos
# ==========================
# Muestra en pantalla los datos de un usuario, usando valores por defecto
# cuando algún campo viene vacío.

mostrar_datos() {
    local usuario="$1"
    local comentario="$2"
    local home="$3"
    local crear="$4"
    local shell="$5"
    local home_vacio="${6:-0}"  # Indica si el home fue generado por defecto (1) o no (0)
    
    local mostrar_comentario="$comentario"
    local mostrar_home="$home"
    local mostrar_shell="$shell"
    local mostrar_crear="$crear"
    
    # Si algún campo está vacío, se muestra "<valor por defecto>"
    if [ -z "$comentario" ]; then mostrar_comentario="<valor por defecto>"; fi
    if [ -z "$home" ] || [ "$home_vacio" -eq 1 ]; then mostrar_home="<valor por defecto>"; fi
    if [ -z "$shell" ]; then mostrar_shell="<valor por defecto>"; fi
    if [ -z "$crear" ]; then mostrar_crear="<valor por defecto>"; fi
    
    echo -e "\tUsuario: $usuario"
    echo -e "\tComentario: $mostrar_comentario"
    echo -e "\tDir home: $mostrar_home"
    echo -e "\tAsegurado existencia de directorio home: $mostrar_crear"
    echo -e "\tShell por defecto: $mostrar_shell"
    echo "-------------------------------------------------------------"
    echo ""
}

# ==========================
# 3. PARSEO DE PARÁMETROS
# ==========================
# Soporta:
#   -i           -> mostrar info detallada
#   -c PASSWORD  -> asignar esa contraseña a los usuarios
#   archivo      -> archivo de entrada con líneas usuario:comentario:home:crear:shell

while [ $# -gt 0 ]; do
    case "$1" in
        -i)
            param_i=true          # Activa modo información
            ;;
        -c)
            param_c=true          # Indica que se usará una contraseña para los usuarios
            shift                # Avanza al argumento siguiente (la contraseña)
            if [ -z "$1" ]; then
                echo "Error: falta contraseña después de -c" >&2
                exit 7
            fi

            # Evita que se pase un archivo .txt como contraseña
            if echo "$1" | grep -Eq '\.txt$'; then
                echo "Error: el argumento después de -c no puede ser un archivo .txt" >&2
                exit 8
            fi
            password="$1"        # Guarda la contraseña para usar luego
            ;;
        -*)
            echo "Error: parámetro inválido '$1'" >&2
            exit 2
            ;;
        *)
            archivo="$1"         # Primer parámetro que no es opción se toma como archivo
            ;;
    esac
    shift                        # Avanza al siguiente parámetro
done

# ==========================
# 4. VALIDACIONES DEL ARCHIVO
# ==========================
# Verifica que se haya indicado un archivo válido y legible.

if [ -z "$archivo" ]; then
    echo "Error: no se especificó archivo" >&2
    exit 1
fi

if [ ! -e "$archivo" ]; then
    echo "Error: el archivo '$archivo' no existe" >&2
    exit 3
fi

if [ ! -f "$archivo" ]; then
    echo "Error: '$archivo' no es un archivo regular" >&2
    exit 4
fi

if [ ! -r "$archivo" ]; then
    echo "Error: no se tienen permisos de lectura sobre '$archivo'" >&2
    exit 5
fi

# ==========================
# 5. PROCESAMIENTO DEL ARCHIVO LÍNEA POR LÍNEA
# ==========================
# Formato esperado por línea: usuario:comentario:home:crear:shell
# - crear = SI -> crear usuario y garantizar home
# - crear = NO o vacío -> crear usuario sin asegurar home (-M)

while read -r linea; do
    # Saltar líneas vacías
    if [ -z "$linea" ]; then
        continue
    fi

    # Validar que tenga 5 campos separados por ":"
    if ! echo "$linea" | egrep -q '^.*:.*:.*:.*:.*$' ; then
        echo "Error: sintaxis incorrecta en línea '$linea'" >&2
        exit 6
    fi

    # Separar campos por ":"
    IFS=":" read -r usuario comentario home crear shell <<< "$linea"
    
    # ======================
    # 5.1. CASO: USUARIO YA EXISTE
    # ======================
    if grep -q "^$usuario:" /etc/passwd; then
        echo "El usuario $usuario ya EXISTE. Se modificaron las parametros adicionales."
        
        # Modificar solo los campos que vienen con valor
        if [ -n "$comentario" ]; then
            usermod -c "$comentario" "$usuario" &>/dev/null
        fi
        
        if [ -n "$home" ]; then
            usermod -d "$home" "$usuario" &>/dev/null
        fi
        
        if [ -n "$shell" ]; then
            usermod -s "$shell" "$usuario" &>/dev/null
        fi
        
        # Mostrar datos si está activado el param i
        if [ "$param_i" = true ]; then
            mostrar_datos "$usuario" "$comentario" "$home" "$crear" "$shell"
        fi

        # Asignar contraseña si está activado el param -c
        if [ "$param_c" = true ] && [ -n "$password" ]; then
            echo "$password" | passwd --stdin "$usuario" &>/dev/null
        fi

        modi=$((modi+1))   # Incrementa contador de usuarios modificados

    # ======================
    # 5.2. CASO: USUARIO NO EXISTE (CREACIÓN)
    # ======================
    else
        home_vacio=0       # Marca si el home se generó por defecto

        # --- Caso crear = "SI": crear usuario y directorio home ---
        if [ "$crear" = "SI" ]; then
            # Si se especificó un home, verificar que no esté ya en uso por otro usuario
            if [ -n "$home" ] && grep -q "^[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:$home:" /etc/passwd; then
                echo "ATENCION: el directorio home '$home' ya está siendo usado por otro usuario. Cambia el nombre de la home." >&2
                continue   # Salta a la siguiente línea del archivo sin crear este usuario
            fi
	if [ -z "$home" ]; then
        home="/home/$usuario"
        home_vacio=1
	fi

            useradd -c "$comentario" -d "$home" -s "$shell" -m "$usuario"   # -m crea el home
            
            # Asignar contraseña si corresponde
            if [ "$param_c" = true ] && [ -n "$password" ]; then
                echo "$password" | passwd --stdin "$usuario" &>/dev/null
            fi

            # Verificar creación exitosa consultando /etc/passwd
            if grep -q "^$usuario:" /etc/passwd; then
                echo "Usuario $usuario creado correctamente."
                if [ "$param_i" = true ]; then
                    echo -e "Usuario $usuario creado con éxito con datos indicados:"
                    mostrar_datos "$usuario" "$comentario" "$home" "$crear" "$shell"
                fi
                contador=$((contador+1))   # Incrementa contador de usuarios creados
            else
                echo "ATENCION: el usuario $usuario no pudo ser creado"
            fi

        # --- Caso crear = "NO" o vacío: crear usuario sin asegurar home ---
        elif [ "$crear" = "NO" ] || [ -z "$crear" ]; then
            # Si no viene home, usar /home/usuario como valor por defecto
            if [ -z "$home" ]; then
                home="/home/$usuario"
                home_vacio=1              # Marca que el home fue asumido por defecto
            fi

            # Verificar que el home no esté ya siendo usado por otro usuario
            if [ -n "$home" ] && grep -q "^[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:$home:" /etc/passwd; then
                echo "ATENCION: el directorio home '$home' ya está siendo usado por otro usuario. Cambia el nombre de la home." >&2
                continue   # Salta a la siguiente línea del archivo sin crear este usuario
            fi

            useradd -c "$comentario" -d "$home" -s "$shell" -M "$usuario"   # -M no crea directorio home
            
            # Asignar contraseña si corresponde
            if [ "$param_c" = true ] && [ -n "$password" ]; then
                echo "$password" | passwd --stdin "$usuario" &>/dev/null
            fi

            # Verificar creación exitosa
            if grep -q "^$usuario:" /etc/passwd; then
                if [ "$param_i" = true ]; then
                    echo "Usuario $usuario se ha creado correctamente."
                    echo -e "Usuario $usuario creado con éxito con datos indicados:"
                    mostrar_datos "$usuario" "$comentario" "$home" "$crear" "$shell" "$home_vacio"
                fi
                contador=$((contador+1))
            else
                echo "ATENCION: el usuario $usuario no pudo ser creado" >&2
            fi
        fi
    fi
    
done < "$archivo"

# ==========================
# 6. RESÚMEN FINAL
# ==========================

if [ "$modi" -ne 0 ]; then
    echo "Se han modificado $modi usuarios con exito"
fi

if [ "$contador" -ne 0 ]; then
    echo "Se han creado $contador usuarios con exito"
fi
