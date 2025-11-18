#!/bin/bash

flag_i=false
flag_c=false
password=""
archivo=""
contador=0
modi=0

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
		echo "El usuario $usuario ya EXISTIA. Se modificaron las parametros adicionales."
		useradd -c "$comentario" -d "$home" -s "$shell" -m "$usuario" &>/dev/null
		echo "$password" | passwd --stdin "$usuario" &>/dev/null
        	mostrar_comentario=$comentario
                mostrar_home=$home
          	            mostrar_shell=$shell
                            mostrar_crear=$crear
            		    if [ -z "$comentario" ]; then mostrar_comentario="<valor por defecto>"; fi
                            if [ -z "$home" ]; then mostrar_home="<valor por defecto>"; fi
                            if [ -z "$shell" ]; then mostrar_shell="<valor por defecto>"; fi
                            if [ -z "$crear" ]; then mostrar_crear="<valor por defecto>"; fi
           		    echo -e "\tComentario: $mostrar_comentario"
           		    echo -e "\tDir home: $mostrar_home"
           		    echo -e "\tAsegurado existencia de directorio home: $mostrar_crear"
           		    echo -e "\tShell por defecto: $mostrar_shell"
			    echo "-------------------------------------------------------------"
			    echo ""
		modi=$((modi+1))
	else
		home_vacio=0
		if [ "$crear" = "SI" ];then
			useradd -c "$comentario" -d "$home" -s "$shell" -m "$usuario"
			echo "$password" | passwd --stdin "$usuario" &>/dev/null
			if grep -q "^$usuario:" /etc/passwd; then
			    echo "Usuario $usuario creado correctamente."
        	            mostrar_comentario=$comentario
            		    mostrar_home=$home
          	            mostrar_shell=$shell
                            mostrar_crear=$crear
            		    if [ -z "$comentario" ]; then mostrar_comentario="<valor por defecto>"; fi
                            if [ -z "$home" ]; then mostrar_home="<valor por defecto>"; fi
                            if [ -z "$shell" ]; then mostrar_shell="<valor por defecto>"; fi
                            if [ -z "$crear" ]; then mostrar_crear="<valor por defecto>"; fi

           		    echo -e "Usuario $usuario creado con éxito con datos indicados:"
           		    echo -e "\tComentario: $mostrar_comentario"
           		    echo -e "\tDir home: $mostrar_home"
           		    echo -e "\tAsegurado existencia de directorio home: $mostrar_crear"
           		    echo -e "\tShell por defecto: $mostrar_shell"
			    echo "-------------------------------------------------------------"
			    echo ""
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
			echo "$password" | passwd --stdin "$usuario" &>/dev/null
			if grep -q "^$usuario:" /etc/passwd; then
				echo "Usuario $usuario se ha creado correctamente."
        	                mostrar_comentario=$comentario
        	                mostrar_home=$home
          	                mostrar_shell=$shell
                                mostrar_crear=$crear
            		        if [ -z "$comentario" ]; then mostrar_comentario="<valor por defecto>"; fi
                            	if [ -z "$home" ] || [ "$home_vacio" -eq 1 ]; then mostrar_home="<valor por defecto>"; fi
                        	if [ -z "$shell" ]; then mostrar_shell="<valor por defecto>"; fi
                                if [ -z "$crear" ]; then mostrar_crear="<valor por defecto>"; fi

           		       echo -e "Usuario $usuario creado con éxito con datos indicados:"
           		       echo -e "\tComentario: $mostrar_comentario"
           		       echo -e "\tDir home: $mostrar_home"
           		       echo -e "\tAsegurado existencia de directorio home: $mostrar_crear"
           		       echo -e "\tShell por defecto: $mostrar_shell"
			      echo "-------------------------------------------------------------"
			      echo ""
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


