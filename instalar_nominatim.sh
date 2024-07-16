#!/bin/bash

# Variables
COUNTRY1="central-america"
COUNTRY2="mexico"
NOMINATIM_IMAGE="mediagis/nominatim:4.4"
NOMINATIM_PASSWORD="clave_muy_segura_password"
DATA_DIR="./data"
COMBINED_PBF="${DATA_DIR}/combined.osm.pbf"
SORTED_PBF="${DATA_DIR}/sorted-combined.osm.pbf"

# Actualizar y instalar dependencias
echo "Actualizando sistema e instalando dependencias..."
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y wget curl gnupg lsb-release

# Instalar Docker
echo "Instalando Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Instalar Docker Compose
echo "Instalando Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Instalar Osmium
echo "Instalando Osmium..."
sudo apt-get install -y osmium-tool

# Crear directorio de datos
mkdir -p $DATA_DIR

# Descargar archivos PBF
echo "Descargando datos de $COUNTRY1 y $COUNTRY2..."
wget -O ${DATA_DIR}/${COUNTRY1}-latest.osm.pbf http://download.geofabrik.de/north-america/${COUNTRY1}-latest.osm.pbf
wget -O ${DATA_DIR}/${COUNTRY2}-latest.osm.pbf http://download.geofabrik.de/north-america/${COUNTRY2}-latest.osm.pbf

# Combinar archivos PBF
echo "Combinando archivos PBF..."
osmium merge ${DATA_DIR}/${COUNTRY1}-latest.osm.pbf ${DATA_DIR}/${COUNTRY2}-latest.osm.pbf -o $COMBINED_PBF

# Ordenar archivo combinado
echo "Ordenando archivo PBF combinado..."
osmium sort $COMBINED_PBF -o $SORTED_PBF

# Crear archivo docker-compose.yml
echo "Creando archivo docker-compose.yml..."
cat <<EOL > docker-compose.yml
version: "3"

services:
    nominatim:
        container_name: nominatim
        image: $NOMINATIM_IMAGE
        ports:
            - "8080:8080"
        environment:
            NOMINATIM_PASSWORD: $NOMINATIM_PASSWORD
            REVERSE_ONLY: "true"
            IMPORT_STYLE: address
            THREADS: 2
        volumes:
            - nominatim-data:/var/lib/postgresql/14/main
            - ./data:/nominatim/data
            - nominatim-flatnode:/nominatim/flatnode
        shm_size: 1gb

volumes:
    nominatim-data:
    nominatim-flatnode:
EOL

# Iniciar contenedor y esperar a que se configure
echo "Iniciando contenedor Docker..."
docker-compose up -d

# Importar datos
echo "Importando datos en Nominatim..."
docker exec -it nominatim bash -c "nominatim import --osm-file /nominatim/data/sorted-combined.osm.pbf --threads 2"

# Reiniciar contenedor para aplicar cambios
echo "Reiniciando contenedor Docker..."
docker-compose restart

echo "Proceso completado. Nominatim está configurado y ejecutándose."
