#!/bin/sh
# Arranca los 12 servicios dentro del mismo contenedor (Railway).
#
# Orden: primero los que nadie llama (inventory, category, user, promotion,
# payment, shipping, review, warranty), después los que dependen de otros
# (product, order, auth) y al final el Gateway. No hay Eureka: cada servicio
# toma la URL de los demás de variables *_SERVICE_URL que apuntan a
# http://localhost:<puerto>, porque todos viven en este contenedor.
#
# Los logs de cada servicio van a la consola (stdout) con un prefijo, para que
# Railway los muestre en "View logs" y se pueda diagnosticar. También quedan en
# /app/logs/<servicio>.log dentro del contenedor.
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

# Arranca un servicio con su puerto fijo. Su salida va a la consola con prefijo
# (y en paralelo a un archivo), para que sea visible en los logs de Railway.
arrancar() {
  nombre="$1"; puerto="$2"
  PORT="$puerto" java -jar "$JARS/$nombre.jar" 2>&1 \
    | sed -u "s/^/[$nombre] /" \
    | tee "$LOGS/$nombre.log" &
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

echo "[arranque] los 12 servicios están en marcha; esperando a que el Gateway responda…"

# Espera activa: informa en el log si el Gateway llega a responder en :8080.
# Sirve para saber desde los logs de Railway si el contenedor está sano.
(
  for i in $(seq 1 60); do
    sleep 5
    if java -version >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
      if curl -fs "http://localhost:8080/actuator/health" >/dev/null 2>&1; then
        echo "[salud] el Gateway responde en :8080 tras $((i*5))s"
        exit 0
      fi
    fi
  done
  echo "[salud] el Gateway NO respondió en :8080 tras 300s; revisa los logs de api-gateway" >&2
) &

# Mantiene vivo el contenedor (si el PID 1 terminara, Railway lo reiniciaría).
wait
