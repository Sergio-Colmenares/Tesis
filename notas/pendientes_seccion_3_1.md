# Pendientes de la Sección 3.1 (Procesamiento)

## Decisiones del autor
- **`I_B` y descriptores de perfil:** opciones A/B/C en `notas/tendencia_vertical.md`. Después de decidir, reescribir de forma explícita la narración de `I_B` (3.1.7).
- **Diagrama de flujo:** ubicación (introducción de la Metodología o inicio de 3.1) y formato (horizontal: página apaisada).
- **Párrafo de la limitación del crosstalk:** se retiró de la Metodología y está guardado en `notas/crosstalk_resumen.md`, pendiente de ubicar en Resultados.

## Verificaciones con datos
- **Rango real del percentil de fondo** (texto: ~32–39 %):
  `r = mad(G.E1,1,2) ./ (prctile(G.E1,95,2) - prctile(G.E1,5,2)); p = min(45, max(25, 40 - 20*r)); [min(p) median(p) max(p)]`
- **Fracción de píxeles reemplazados por los filtros SyP 5×5 y de líneas 5×1:**
  `100*mean(G.E1(:) ~= G.Ecorr(:)), 100*mean(G.Eclean(:) ~= G.Efondo(:))`
  Si la del 5×1 es alta, ajustar la frase «solo se modifican los píxeles anómalos».

## Problemas de método identificados (sin cambiar todavía)
- **Corrección de fondo por línea:**
  1. la regla adaptativa casi no adapta (p ≈ 32–39 %; las cotas 25/45 no se usan);
  2. hay sesgo en filas con mucha red (CNTs alineados con la línea de barrido): el fondo se sobreestima y la fila se oscurece;
  3. solo corrige variaciones entre filas, no fondos 2D (caso `0a-2`);
  4. el error independiente de b_i entre filas podría explicar la fracción alta de reemplazos del filtro 5×1 (hipótesis).
- **`medfilt2` con relleno de ceros:** en los bordes, la mediana se sesga hacia 0 y la última fila se reemplaza entera (visible en la figura de SyP). Alternativa: `'symmetric'`.
- **Umbral global `th(1)`:** cae dentro del fondo y es inestable frente a cambios pequeños (ver `notas/crosstalk_resumen.md`). Se mantiene como está por decisión del autor.
- **El primer A₅₀ sobre `M_G`** es redundante: no cambia el resultado (documentado en el texto).

## Versión final: pauta de figuras (resolución nativa)
Pauta 13: cada figura debe ser nítida y en formato vectorizado (PDF). Para la versión final, todos los mapas deben poder verse píxel a píxel al hacer zoom.
- **Diagrama de la metodología:** ya cumple (PDF vectorial, miniaturas de 1024×1024 sin interpolar).
- **Figuras `met_*`:** son PDF, pero rasterizadas a ~500 px por panel (`exportgraphics(..., 'ContentType', 'image')`). Las fuentes para rehacerlas ya están en `documento/figuras/metodologia/met_*.tex`; falta generar los paneles con el bloque de MATLAB (carpeta `paneles/`) y compilar.
- **Figuras del Cap. 4 y anexos:** revisar con el mismo criterio cuando se trabajen.
