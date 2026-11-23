# Despliegue en Railway + Vercel

Guía para dejar el backend corriendo en internet y que la página de Vercel use
datos reales compartidos entre todos (lo que hoy no ocurre: Vercel compila con
`http://localhost:8080` incrustado y cada visitante apunta a su propia máquina).

El despliegue usa **un solo contenedor** (`Dockerfile.railway`) que arranca los
12 servicios dentro de sí mismo, sin Eureka (el perfil `prod` usa URLs fijas que
apuntan a `http://localhost:<puerto>` entre procesos del mismo contenedor). Una
sola URL pública: el Gateway.

Archivos que agregó este despliegue (todos en la raíz del backend):

- `Dockerfile.railway` — compila los 12 módulos y arma la imagen.
- `arranque-railway.sh` — lanza los 12 procesos en orden dentro del contenedor.
- `railway.json` — le dice a Railway qué Dockerfile usar y cómo comprobar salud.

Verificado en local: la imagen construye, los 12 servicios arrancan contra un
PostgreSQL real, el Gateway responde `/actuator/health`, el catálogo se sirve,
el login devuelve token y un cambio de stock hecho por el operador **lo ve un
cliente anónimo** (que es justo lo que fallaba antes).

---

## Paso 1 — Subir el backend a GitHub

Los archivos nuevos ya están en el repo local. Hay que commitearlos y empujarlos
a `main` (el remoto es `github.com/LordLitox/GameHubStoreFullstack-Backend`):

```sh
cd Duoc-Fullstack2-GameHubStore-BackEnd-main
git add Dockerfile.railway arranque-railway.sh railway.json
git commit -m "Despliegue todo-en-uno para Railway (Dockerfile, arranque y config)"
git push origin main
```

---

## Paso 2 — Crear el proyecto en Railway

1. Entra a https://railway.app y crea una cuenta (con GitHub).
2. **New Project → Deploy from GitHub repo** → elige `GameHubStoreFullstack-Backend`.
   Railway detecta `railway.json` y usará `Dockerfile.railway` automáticamente.
3. **No hagas deploy todavía**: primero agrega la base y las variables (pasos 3 y 4).

---

## Paso 3 — Agregar PostgreSQL

En el mismo proyecto: **New → Database → Add PostgreSQL**.

Railway crea la base y expone variables (`PGHOST`, `PGPORT`, `PGUSER`,
`PGPASSWORD`, `PGDATABASE`). El servicio backend necesita una sola variable
`DB_URL` en formato JDBC. En el servicio backend → **Variables**, agrega:

| Variable | Valor |
| --- | --- |
| `DB_URL` | `jdbc:postgresql://${{Postgres.PGHOST}}:${{Postgres.PGPORT}}/${{Postgres.PGDATABASE}}` |
| `DB_USUARIO` | `${{Postgres.PGUSER}}` |
| `DB_CLAVE` | `${{Postgres.PGPASSWORD}}` |

(Las referencias `${{Postgres.…}}` las resuelve Railway solo; `Postgres` es el
nombre del servicio de base de datos. Si le pusiste otro nombre, cámbialo.)

---

## Paso 4 — Las demás variables del backend

En el servicio backend → **Variables**, agrega:

| Variable | Valor | Para qué |
| --- | --- | --- |
| `SPRING_PROFILES_ACTIVE` | `prod` | Activa PostgreSQL y las URLs fijas (ya viene en el Dockerfile, pero déjalo explícito) |
| `JWT_SECRETO` | una cadena de **al menos 32 caracteres** | Firma y valida los tokens; igual en todos los servicios |
| `CLAVE_INTERNA` | una cadena secreta | Clave de las rutas `/internal/**` entre servicios |
| `CORS_ORIGENES` | `https://TU-APP.vercel.app,http://localhost:5173` | Orígenes permitidos (pon tu dominio real de Vercel) |
| `DATOS_INICIALES` | `true` | Carga los datos de ejemplo la primera vez que la base está vacía |

> Las variables `*_SERVICE_URL` **no** hay que definirlas: `arranque-railway.sh`
> las fija a `http://localhost:<puerto>` porque los 12 procesos viven en el
> mismo contenedor.

---

## Paso 5 — Generar el dominio público

En el servicio backend → **Settings → Networking → Generate Domain**. Railway te
da algo como `https://gamehub-backend-production.up.railway.app`.

**Esa URL + `/api/v1` es la que va en Vercel** (paso 6). Ejemplo:
`https://gamehub-backend-production.up.railway.app/api/v1`

Antes de seguir, comprueba que el backend está vivo (tarda 1–3 min en arrancar
los 12 servicios la primera vez):

```sh
curl https://TU-DOMINIO.up.railway.app/actuator/health
# {"groups":["liveness","readiness"],"status":"UP"}

curl https://TU-DOMINIO.up.railway.app/api/v1/productos
# debe devolver el catálogo en JSON
```

---

## Paso 6 — Apuntar Vercel al backend

En Vercel → tu proyecto → **Settings → Environment Variables**:

| Nombre | Valor | Entornos |
| --- | --- | --- |
| `VITE_API_URL` | `https://TU-DOMINIO.up.railway.app/api/v1` | Production, Preview, Development |

Luego **Redeploy** (Deployments → ⋯ → Redeploy). Es obligatorio: Vite incrusta
la variable en el momento del build, guardarla no basta.

---

## Paso 7 — Probar

1. Abre tu página de Vercel. El catálogo debe mostrar datos reales (no el
   respaldo local).
2. Inicia sesión con una cuenta de ejemplo (clave `clave123`):
   - `ana@gamehub.test` → ADMIN (panel `/admin`)
   - `luis@gamehub.test` → OPERADOR/Vendedor (panel `/vendedor`)
3. Cambia algo (por ejemplo el stock desde `/vendedor → Inventario`, o un
   producto desde `/admin`).
4. Pídele a otra persona que abra **la misma URL de Vercel** y recargue: debe ver
   el cambio. Ahora sí comparten backend y base de datos.

---

## Notas y advertencias

- **Arranque lento**: 12 JVM en un contenedor tardan 1–3 min en estar todos
  arriba. El healthcheck de Railway espera hasta 5 min (`railway.json`).
- **Memoria**: si Railway te reinicia el contenedor por memoria, sube el plan o
  baja `MaxRAMPercentage` en `Dockerfile.railway` (hoy 45 %).
- **Plan gratuito**: si el servicio se duerme por inactividad, el primer acceso
  tras un rato tarda en despertar. Para la defensa, abre la página unos minutos
  antes o pásate a un plan que no duerma.
- **Cambiar el CORS**: si tu dominio de Vercel cambia, actualiza `CORS_ORIGENES`
  en Railway y redespliega el backend (no el frontend).
- **Actualizar el backend**: cada `git push` a `main` dispara un redeploy
  automático en Railway.
