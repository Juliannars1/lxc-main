source .env
CONTAINER_PREFIX=${CONTAINER_PREFIX}

LXC_NAME_PHP_CODEIGNITER="php-codeigniter"
LXC_NAME_PHP_WORDPRESS="php-wordpress"
LXC_NAME_NGINX="nginx"
LXC_NAME_MYSQL="mysql"

SUDO_USER="root"
DB_NAME="fiduprevisora"

# Eliminar contenedores si existen
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    if lxc list | grep -q "${container}"; then
        lxc delete "${container}" --force
    fi
done

# Crear contenedores
lxc init ubuntu:20.04 "${LXC_NAME_PHP_CODEIGNITER}" --profile default
lxc init ubuntu:20.04 "${LXC_NAME_PHP_WORDPRESS}" --profile default
lxc init ubuntu:20.04 "${LXC_NAME_NGINX}" --profile default
lxc init ubuntu:20.04 "${LXC_NAME_MYSQL}" --profile default

# Configurar directorios
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    lxc config device add "${container}" www disk source="${PWD}" path=/www
done

# Iniciar contenedores
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    lxc start "${container}"
done

# Aplicar redes
for container in "${LXC_NAME_PHP_CODEIGNITER}" "${LXC_NAME_PHP_WORDPRESS}" "${LXC_NAME_NGINX}" "${LXC_NAME_MYSQL}"; do
    lxc exec "${container}" -- ip link add br0 type bridge
    lxc exec "${container}" -- ip addr add 10.0.3.21/24 dev eth0 brd + scope global
    lxc exec "${container}" -- ip route add default via 10.0.3.254 dev eth0
    lxc exec "${container}" -- ip route add 10.0.3.0/24 via 10.0.3.254 dev eth0
done

# Configurar puertos expuestos
lxc config device add "${LXC_NAME_PHP_CODEIGNITER}" myport80 proxy listen=tcp:0.0.0.0:8000 connect=tcp:10.0.3.21:8000
lxc config device add "${LXC_NAME_PHP_WORDPRESS}" myport80 proxy listen=tcp:0.0.0.0:8000 connect=tcp:10.0.3.22:8000
lxc config device add "${LXC_NAME_NGINX}" myport80 proxy listen=tcp:0.0.0.0:8000 connect=tcp:10.0.3.23:8000
lxc config device add "${LXC_NAME_MYSQL}" myport3306 proxy listen=tcp:0.0.0.0:3306 connect=tcp:10.0.3.24:3306

# Instalación de paquetes dentro de los contenedores
lxc exec "${LXC_NAME_NGINX}" -- apt update && apt install -y nginx
lxc exec "${LXC_NAME_PHP_CODEIGNITER}" -- apt update && apt install -y php7.4-fpm php7.4-cli php7.4-mysql php7.4-mbstring php7.4-xml
lxc exec "${LXC_NAME_PHP_WORDPRESS}" -- apt update && apt install -y php8.3-fpm php8.3-cli php8.3-mysql php8.3-mbstring php8.3-xml
