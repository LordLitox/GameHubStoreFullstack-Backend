#!/bin/sh
# Arranca los 12 servicios dentro del mismo contenedor (Railway).
#
# Orden: primero los que nadie llama (inventory, category, user, promotion,
# payment, shipping, review, warranty), después los que dependen de otros
# (product, order, auth) y al final el Gateway. No hay Eureka: cada servicio
# toma la URL de los demás de variables *_SERVICE_URL que apuntan a
# http://localhost:<puerto>, porque todos viven en este contenedor.
#
# Si un servicio se cae, el contenedor no se reinicia solo (el PID 1 sigue vivo
# esperando). Railway reinicia el contenedor completo si el PID 1 termina, por
# eso al final este script espera indefinidamente; para un reinicio limpio basta
# con "Redeploy" en Railway. Los logs de cada servicio quedan en /app/logs.
set -eu

JARS=/app/jars
LOGS=/app/logs
mkdir -p "$LOGS"

# Variables que el perfil prod exige. Railway las inyecta; el script falla con
# un mensaje claro si falta alguna, en vez de arrancar a medias.
: "${JWT_SECRETO:?Falta JWT_SECRETO}"
: "${CLAVE_INTERNA:?Falta CLAVE_INTERNA}"
: "${DB_URL:?Falta DB_URL}"
: "${DB_USUARIO:?Falta DB_USUARIO}"
: "${DB_CLAVE:?Falta DB_CLAVE}"

# El Gateway escucha en el puerto público que da Railway.
export PORT="${PORT:-8080}"

# URLs internas: todos los procesos están en este contenedor.
export AUTH_SERVICE_URL="http://localhost:8081"
export USER_SERVICE_URL="http://localhost:8082"
export CATEGORY_SERVICE_URL="http://localhost:8083"
export PRODUCT_SERVICE_URL="http://localhost:8084"
export INVENTORY_SERVICE_URL="http://localhost:8085"
export PROMOTION_SERVICE_URL="http://localhost:8086"
export ORDER_SERVICE_URL="http://localhost:8087"
export PAYMENT_SERVICE_URL="http://localhost:8088"
export SHIPPING_SERVICE_URL="http://localhost:8089"
export REVIEW_SERVICE_URL="http://localhost:8090"
export WARRANTY_SERVICE_URL="http://localhost:8091"

# Arranca un servicio con su puerto fijo y lo deja en segundo plano.
arrancar() {
  nombre="$1"; puerto="$2"
  PORT="$puerto" java -jar "$JARS/$nombre.jar" >"$LOGS/$nombre.log" 2>&1 &
  echo "[arranque] $nombre -> :$puerto (pid $!)"
}

# ---------- Servicios sin dependencias salientes ----------
arrancar inventory-service  8085
arrancar category-service   8083
arrancar user-service       8082
arrancar promotion-service  8086
arrancar payment-service    8088
arrancar shipping-service   8089
arrancar review-service     8090
arrancar warranty-service   8091

# ---------- Dependen de otros servicios ----------
arrancar product-service    8084
arrancar order-service      8087
arrancar auth-service       8081

# El Gateway va al final: cuando arranque, el resto ya está escuchando.
arrancar api-gateway        8080

echo "[arranque] los 12 servicios están en marcha; logs en $LOGS"
# Mantiene vivo el contenedor (si el PID 1 terminara, Railway lo reiniciaría).
wait
