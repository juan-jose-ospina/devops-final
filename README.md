# Proyecto Final DevOps: API de tareas (estudiante18)

API de tareas en Python (Flask) con base de datos PostgreSQL, desplegada con Docker Compose en el servidor compartido de la clase. Incluye un script de seguridad (DevSecOps) y una función de monitoreo.

## Datos del despliegue

| Dato | Valor |
|---|---|
| Estudiante | estudiante18 |
| Servidor | 178.128.14.98 |
| API | http://178.128.14.98:8018/health |
| Proyecto Compose | `estudiante18` |
| Contenedores | `est18_db` (PostgreSQL 16) y `est18_api` (Flask + gunicorn) |
| Puerto publicado | 8018 (hacia el puerto 5000 del contenedor) |
| Base de datos | No se publica; la API se conecta por la red interna de Docker al puerto 5432 |

## Estructura del repositorio

| Archivo | Descripción |
|---|---|
| `app/` | Código de la API (Flask) y `requirements.txt` |
| `Dockerfile` | Construye la imagen de la API |
| `docker-compose.yml` | Levanta `db` y `api` |
| `.env.example` | Plantilla de variables de entorno (el `.env` real no se sube) |
| `seguridad.sh` | Escaneos DevSecOps y función `monitorear` |
| `reportes/` | Resultados de Gitleaks, Semgrep, Syft, Trivy y Hadolint |
| `monitoreo.log` | Registro con fecha de cada monitoreo |

## Comandos usados, en orden

### 1. Conexión y obtención del código
```bash
ssh estudiante18@178.128.14.98
cd ~
git clone https://github.com/juan-jose-ospina/devops-final
cd devops-final
ls -la
git config --global user.name "juan jose ospina"
git config --global user.email "juan.ospina14@utp.edu.co"
cat INSTRUCCIONES.md
cat .gitignore
```

### 2. Ajustes de Git y organización de carpetas
```bash
echo ".DS_Store" >> .gitignore
git rm --cached .DS_Store
rm .DS_Store
git add .gitignore
git commit -m "Ignorar .DS_Store y quitarlo del repositorio"
cd ~
mkdir ~/estudiante18
mv ~/devops-final ~/estudiante18/devops-final
cd ~/estudiante18/devops-final
git remote -v
git log --oneline
```

### 3. Revisión del servidor compartido
```bash
docker ps -a
docker compose ls
docker volume ls | grep estudiante18
cd ~/taller-postgres
docker compose down
cd ~/estudiante18/devops-final
```
Se detuvo solo el despliegue propio del taller anterior (sin borrar volúmenes), porque usaba el mismo nombre de proyecto `estudiante18`. No se tocaron contenedores de otros estudiantes.

### 4. Variables de entorno (el `.env` no se sube a GitHub)
```bash
cp .env.example .env
sed -i 's/^ESTUDIANTE=.*/ESTUDIANTE=estudiante18/; s/^API_PORT=.*/API_PORT=8018/' .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 12)/" .env
grep -v PASSWORD .env
```
`DB_HOST=db` y `DB_PORT=5432`: la base de datos no se publica y no se usa el puerto 54XX.

### 5. Docker Compose
```bash
cat > docker-compose.yml     # contenido en la sección "docker-compose.yml"
docker compose config -q
docker compose up -d --build
docker compose ps
curl http://localhost:8018/health
curl -X POST http://localhost:8018/tareas -H "Content-Type: application/json" -d '{"titulo":"Primera tarea"}'
curl http://localhost:8018/tareas
git status
git add docker-compose.yml
git commit -m "Agregar docker-compose.yml con API y base de datos"
```

### 6. Publicar en GitHub
```bash
git config --global credential.helper 'cache --timeout=3600'
git push origin main
```
La autenticación se hizo con un Personal Access Token de GitHub (no se guarda en el repositorio).

### 7. DevSecOps y monitoreo
```bash
cat > seguridad.sh           # contenido en el archivo seguridad.sh del repositorio
chmod +x seguridad.sh
./seguridad.sh
ls -lh reportes/
cat monitoreo.log
GOGC=20 GOMEMLIMIT=400MiB syft estudiante18-api:latest -q --select-catalogers python -o cyclonedx-json > reportes/sbom.json
git add seguridad.sh
git commit -m "Agregar script seguridad.sh con herramientas DevSecOps y funcion monitorear"
git add -f reportes/ monitoreo.log
git commit -m "Agregar reportes de seguridad y registro de monitoreo"
git push origin main
```

## docker-compose.yml

```yaml
name: estudiante18

services:
  db:
    image: postgres:16-alpine
    container_name: est18_db
    env_file: .env
    volumes:
      - tareas_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  api:
    build: .
    container_name: est18_api
    env_file: .env
    ports:
      - "8018:5000"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

volumes:
  tareas_data:
```

Decisiones:
- Primera línea `name: estudiante18`, para no compartir red ni volúmenes con otros estudiantes.
- El servicio `db` no tiene `ports`: la base de datos no se publica. Usa el volumen `tareas_data` para persistir los datos.
- El servicio `api` se construye con el `Dockerfile` y se publica en `8018:5000`.
- `depends_on` con `service_healthy` hace que la API espere a que la base de datos esté lista.

## DevSecOps (`seguridad.sh`)

Uso:
```bash
./seguridad.sh              # escaneos + monitoreo
./seguridad.sh monitorear   # solo monitoreo
```

| Herramienta | Qué revisa | Reporte |
|---|---|---|
| Gitleaks | Secretos en el repositorio | `reportes/gitleaks.json` |
| Semgrep | Análisis estático del código (OWASP Top 10) | `reportes/semgrep.json` |
| Syft | SBOM de la imagen `estudiante18-api:latest` | `reportes/sbom.json` |
| Trivy | Vulnerabilidades HIGH y CRITICAL de la imagen | `reportes/trivy.txt` |
| Hadolint | Buenas prácticas del `Dockerfile` | `reportes/hadolint.txt` |

Notas:
- Gitleaks no encontró secretos (el reporte es una lista vacía) y Hadolint no reportó advertencias (archivo vacío).
- Syft se ejecuta solo con los catálogos de Python y con límites de memoria (`GOGC`, `GOMEMLIMIT`), porque el escaneo completo fue terminado por el sistema (`Killed`) por falta de memoria en el servidor compartido.
- Los comandos usan `||` para que el script continúe aunque una herramienta reporte hallazgos.

## Monitoreo (función `monitorear`)

Cada ejecución:
1. Consulta `http://localhost:8018/health` y registra si responde (HTTP 200).
2. Muestra el estado de los contenedores `est18_*`.
3. Muestra los últimos 5 registros de log de `est18_api`.
4. Agrega todo, con fecha y hora, a `monitoreo.log`.

## Seguridad

- El archivo `.env` está en `.gitignore` y nunca se sube; solo se publica `.env.example`.
- La base de datos no se publica en el servidor.
- La imagen corre con un usuario sin privilegios (`appuser`).
