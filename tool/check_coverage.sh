#!/usr/bin/env bash
# Verifica que la cobertura de líneas de las pruebas alcance el mínimo del
# Quality Gate de la wiki (06-cicd-ambientes/pipelines-quality-gate.md: 80 %).
#
# Uso:   tool/check_coverage.sh [mínimo] [reporte lcov]
# Antes: flutter test --coverage   (genera coverage/lcov.info)
set -euo pipefail

MIN="${1:-80}"
LCOV="${2:-coverage/lcov.info}"

if [ ! -f "$LCOV" ]; then
  echo "No se encontró $LCOV. Ejecute primero: flutter test --coverage" >&2
  exit 1
fi

awk -v min="$MIN" '
  /^SF:/ { file = substr($0, 4) }
  /^LF:/ { found += substr($0, 4); file_found[file] = substr($0, 4) }
  /^LH:/ { hit += substr($0, 4); file_hit[file] = substr($0, 4) }
  END {
    if (found == 0) { print "El reporte no tiene líneas instrumentadas."; exit 1 }
    pct = hit * 100 / found
    printf "Cobertura de líneas: %.1f %% (%d de %d) · mínimo: %s %%\n", pct, hit, found, min
    if (pct + 0 < min + 0) {
      print "No se alcanza el mínimo. Archivos con menor cobertura:"
      cmd = "sort -n | head -10"
      for (f in file_found)
        if (file_found[f] > 0)
          printf "  %5.1f %%  %s\n", file_hit[f] * 100 / file_found[f], f | cmd
      close(cmd)
      exit 1
    }
  }
' "$LCOV"
