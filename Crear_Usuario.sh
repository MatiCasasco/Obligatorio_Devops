#!/bin/bash

flag_i=false
flag_c=false
password=""
archivo=""
contador=0
modi=0

# Función para mostrar datos del usuario
mostrar_datos() {
    local usuario="$1"
    local comentario="$2"
    local home="$3"
    local crear="$4"
    local shell="$5"
    local home_vacio="${6:-0}"  # Valor por defecto 0 si no se pasa
    
    local mostrar_comentario="$comentario"
    local mostrar_home="$home"
    local mostrar_shell="$shell"
    local mostrar_crear="$crear"
    
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

while [ $# -gt 0 ]; do
	case "$1" in
	-i)
		flag_i=true
		;;
        -c)
		flag_c=true
		shift
		if [ -z "$1" ]; then
			echo "Error: falta contraseña después de -c" >&2
                	exit 7
		fi

		if echo "$1" | grep -Eq '\.txt$'; then # Poner verificacion de archivo y no extension, tmb directorio.
			echo "Error: el argumento después de -c no puede ser un archivo .txt" >&2
			exit 8
		fi
		password="$1"
           
		;;
        -*)
		echo "Error: parámetro inválido '$1'" >&2
		exit 2
		;;
        *)
		archivo="$1"
		;;
    	esac
    shift
done

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

while read -r linea; do
	if [ -z "$linea" ];then
        	continue
	fi
	if ! echo "$linea" | egrep -q '^.*:.*:.*:.*:.*$' ; then
        	echo "Error: sintaxis incorrecta en línea '$linea'" >&2
        	exit 6
    	fi
	IFS=":" read -r usuario comentario home crear shell <<< "$linea"
	
	if grep -q "^$usuario:" /etc/passwd; then
		echo "El usuario $usuario ya EXISTE. Se modificaron las parametros adicionales."
		
		# Modificar solo los campos que tienen valor usando usermod
		if [ -n "$comentario" ]; then
			usermod -c "$comentario" "$usuario" &>/dev/null
		fi
		
		if [ -n "$home" ]; then
			usermod -d "$home" "$usuario" &>/dev/null
		fi
		
		if [ -n "$shell" ]; then
			usermod -s "$shell" "$usuario" &>/dev/null
		fi
		
		
		
		if [ "$flag_i" = true ]; then
			mostrar_datos "$usuario" "$comentario" "$home" "$crear" "$shell" 
		fi
		if [ "$flag_c" = true ] && [ -n "$password" ]; then
			echo "$password" | passwd --stdin "$usuario" &>/dev/null
		fi
		modi=$((modi+1))
	else
		home_vacio=0
		if [ "$crear" = "SI" ];then
			useradd -c "$comentario" -d "$home" -s "$shell" -m "$usuario"
			if [ "$flag_c" = true ] && [ -n "$password" ];then
				echo "$password" | passwd --stdin "$usuario" &>/dev/null
			fi
			if grep -q "^$usuario:" /etc/passwd; then
			    echo "Usuario $usuario creado correctamente."
			    if [ "$flag_i" = true ];then
				echo -e "Usuario $usuario creado con éxito con datos indicados:"
				mostrar_datos "$usuario" "$comentario" "$home" "$crear" "$shell"
			    fi
			    contador=$((contador+1))
			else
			    echo "ATENCION: el usuario $usuario no pudo ser creado"
			fi
		elif [ "$crear" = "NO" ] || [ -z "$crear" ];then
			if [ -z "$home" ]; then
				home="/home/$usuario"
				home_vacio=1
			fi
			useradd -c "$comentario" -d "$home" -s "$shell" -M "$usuario"
			if [ "$flag_c" = true ] && [ -n "$password" ];then
				echo "$password" | passwd --stdin "$usuario" &>/dev/null
			fi
			if grep -q "^$usuario:" /etc/passwd; then
				if [ "$flag_i" = true ];then
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

if [ "$modi" -ne 0 ];then
	echo "Se han modificado $modi usuarios con exito"
fi

if [ "$contador" -ne 0 ];then
	echo "Se han creado $contador usuarios con exito"
fi
