#!/bin/bash
source .env
CONTAINER_PREFIX=${CONTAINER_PREFIX:-"myproject"}

LXC_NAME_PHP_CODEIGNITER="${CONTAINER_PREFIX}-php-codeigniter"
LXC_NAME_PHP_WORDPRESS="${CONTAINER_PREFIX}-php-wordpress"
LXC_NAME_NGINX="${CONTAINER_PREFIX}-nginx"
LXC_NAME_MYSQL="${CONTAINER_PREFIX}-mysql"

WWW_PATH="/var/www/myproject"
DB_NAME="fiduprevisora"

# Eliminar contenedores si existen
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    if lxc list | grep -qw "${container}"; then
        echo "Deleting container: ${container}"
        lxc delete "${container}" --force
    fi
done

# Crear contenedores
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    lxc init ubuntu:20.04 "${container}" --profile default
done

# Configurar directorios
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    lxc config device add "${container}" www disk source="${WWW_PATH}" path=/www
done

# Iniciar contenedores
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    lxc start "${container}"
done

# Configuración de red persistente
if ! lxc network show mybridge >/dev/null 2>&1; then
    lxc network create mybridge
fi
lxc network attach-profile mybridge default

# Configurar puertos expuestos
lxc config device add "${LXC_NAME_PHP_CODEIGNITER}" myport80 proxy listen=tcp:0.0.0.0:8001 connect=tcp:80
lxc config device add "${LXC_NAME_PHP_WORDPRESS}" myport80 proxy listen=tcp:0.0.0.0:8002 connect=tcp:80
lxc config device add "${LXC_NAME_NGINX}" myport80 proxy listen=tcp:0.0.0.0:8003 connect=tcp:80
lxc config device add "${LXC_NAME_MYSQL}" myport3306 proxy listen=tcp:0.0.0.0:3306 connect=tcp:3306

# Instalación de paquetes dentro de los contenedores
lxc exec "${LXC_NAME_NGINX}" -- bash -c "apt update && apt install -y nginx"
lxc exec "${LXC_NAME_PHP_CODEIGNITER}" -- bash -c "apt update && apt install -y software-properties-common && add-apt-repository -y ppa:ondrej/php && apt update && apt install -y php7.4-fpm php7.4-cli php7.4-mysql php7.4-mbstring php7.4-xml"
lxc exec "${LXC_NAME_PHP_WORDPRESS}" -- bash -c "apt update && apt install -y software-properties-common && add-apt-repository -y ppa:ondrej/php && apt update && apt install -y php8.3-fpm php8.3-cli php8.3-mysql php8.3-mbstring php8.3-xml"
