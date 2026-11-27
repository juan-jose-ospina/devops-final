#!/bin/bash

PUERTO=8018
IMAGEN="estudiante18-api:latest"
DIR_REPORTES="reportes"
LOG="monitoreo.log"

seguridad() {
  mkdir -p "$DIR_REPORTES"

  echo "[1/5] Gitleaks: busqueda de secretos..."
  gitleaks detect --source=. --report-format json \
    --report-path "$DIR_REPORTES/gitleaks.json" \
    || echo "  -> Gitleaks reporto hallazgos"

  echo "[2/5] Semgrep: analisis estatico del codigo..."
  PYTHONWARNINGS="ignore" semgrep scan --config=p/owasp-top-ten \
    --json -o "$DIR_REPORTES/semgrep.json" . \
    || echo "  -> Semgrep reporto hallazgos"

  echo "[3/5] Syft: SBOM de la imagen $IMAGEN..."
  GOGC=20 GOMEMLIMIT=400MiB syft "$IMAGEN" -q --select-catalogers python -o cyclonedx-json > "$DIR_REPORTES/sbom.json" \
    || echo "  -> Syft fallo"

  echo "[4/5] Trivy: vulnerabilidades de la imagen..."
  trivy image --skip-version-check --severity HIGH,CRITICAL \
    -o "$DIR_REPORTES/trivy.txt" "$IMAGEN" \
    || echo "  -> Trivy fallo"

  echo "[5/5] Hadolint: buenas practicas del Dockerfile..."
  hadolint Dockerfile > "$DIR_REPORTES/hadolint.txt" \
    || echo "  -> Hadolint reporto advertencias"

  echo "Reportes guardados en $DIR_REPORTES/"
}

monitorear() {
  local fecha codigo
  fecha=$(date '+%Y-%m-%d %H:%M:%S')
  codigo=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:$PUERTO/health")

  {
    echo "===== MONITOREO $fecha ====="
    if [ "$codigo" = "200" ]; then
      echo "API: OK (HTTP $codigo) en http://localhost:$PUERTO/health"
    else
      echo "API: NO RESPONDE (HTTP $codigo)"
    fi
    echo "--- Estado de contenedores ---"
    docker ps -a --filter "name=est18_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo "--- Ultimos logs de est18_api ---"
    docker logs --tail 5 est18_api 2>&1
    echo
  } | tee -a "$LOG"
}

case "$1" in
  monitorear) monitorear ;;
  *) seguridad; monitorear ;;
esac
