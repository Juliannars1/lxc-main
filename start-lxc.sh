#!/bin/bash

# Cargar variables de entorno
source .env
CONTAINER_PREFIX=${CONTAINER_PREFIX:-"myproject"}

LXC_NAME_PHP_CODEIGNITER="${CONTAINER_PREFIX}-php-codeigniter"
LXC_NAME_PHP_WORDPRESS="${CONTAINER_PREFIX}-php-wordpress"
LXC_NAME_NGINX="${CONTAINER_PREFIX}-nginx"
LXC_NAME_MYSQL="${CONTAINER_PREFIX}-mysql"

WWW_PATH="/var/www/myproject"
DB_NAME="fiduprevisora"

# Verificar si el directorio compartido existe
if [ ! -d "${WWW_PATH}" ]; then
    echo "El directorio ${WWW_PATH} no existe. Creándolo..."
    sudo mkdir -p "${WWW_PATH}"
    sudo chmod -R 755 "${WWW_PATH}"
    sudo chown -R $USER:$USER "${WWW_PATH}"
fi

# Eliminar contenedores si existen
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    if lxc list | grep -qw "${container}"; then
        echo "Eliminando contenedor: ${container}"
        lxc delete "${container}" --force
    fi
done

# Crear contenedores
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    echo "Creando contenedor: ${container}"
    lxc init ubuntu:20.04 "${container}" --profile default || {
        echo "Error al crear el contenedor ${container}"
        exit 1
    }
done

# Configurar directorios en los contenedores
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    echo "Configurando dispositivo www para el contenedor: ${container}"
    if lxc config device show "${container}" | grep -qw "www"; then
        lxc config device remove "${container}" www
    fi
    lxc config device add "${container}" www disk source="${WWW_PATH}" path=/www || {
        echo "Error al configurar el dispositivo www en ${container}"
        exit 1
    }
done

# Iniciar contenedores
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    echo "Iniciando contenedor: ${container}"
    lxc start "${container}" || {
        echo "Error al iniciar el contenedor ${container}"
        exit 1
    }
done

# Configuración de red persistente
if ! lxc network show mybridge >/dev/null 2>&1; then
    echo "Creando red mybridge..."
    lxc network create mybridge || {
        echo "Error al crear la red mybridge"
        exit 1
    }
fi
lxc network attach-profile mybridge default

# Configurar puertos expuestos
declare -A port_mapping=(
    ["${LXC_NAME_PHP_CODEIGNITER}"]="8001"
    ["${LXC_NAME_PHP_WORDPRESS}"]="8002"
    ["${LXC_NAME_NGINX}"]="8003"
    ["${LXC_NAME_MYSQL}"]="3306"
)
for container in "${!port_mapping[@]}"; do
    port="${port_mapping[$container]}"
    echo "Configurando puerto ${port} para el contenedor: ${container}"
    if lxc config device show "${container}" | grep -qw "myport${port}"; then
        lxc config device remove "${container}" "myport${port}"
    fi
    lxc config device add "${container}" "myport${port}" proxy listen=tcp:0.0.0.0:"${port}" connect=tcp:"${port}" || {
        echo "Error al configurar el puerto ${port} en ${container}"
        exit 1
    }
done

# Instalación de paquetes dentro de los contenedores
declare -A install_commands=(
    ["${LXC_NAME_NGINX}"]="apt update && apt install -y nginx"
    ["${LXC_NAME_PHP_CODEIGNITER}"]="apt update && apt install -y software-properties-common && add-apt-repository -y ppa:ondrej/php && apt update && apt install -y php7.4-fpm php7.4-cli php7.4-mysql php7.4-mbstring php7.4-xml"
    ["${LXC_NAME_PHP_WORDPRESS}"]="apt update && apt install -y software-properties-common && add-apt-repository -y ppa:ondrej/php && apt update && apt install -y php8.3-fpm php8.3-cli php8.3-mysql php8.3-mbstring php8.3-xml"
)
for container in "${!install_commands[@]}"; do
    echo "Instalando paquetes en el contenedor: ${container}"
    lxc exec "${container}" -- bash -c "${install_commands[$container]}" || {
        echo "Error al instalar paquetes en ${container}"
        exit 1
    }
done

echo "Todos los contenedores han sido configurados correctamente."
