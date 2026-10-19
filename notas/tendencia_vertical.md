# Tendencia vertical del canal eléctrico: origen instrumental

Datos: `resultados/tendencia_vertical.csv` (81 mediciones). Perfiles calculados sobre `I_B` (mediana por fila y por columna, suavizados con mediana móvil de 101 px). Todas las magnitudes están en unidades de la MAD de cada medición.

| Evidencia | Resultado |
|---|---|
| Cociente entre el rango vertical (eje del tiempo) y el horizontal (a lo largo de la línea) | Mediana **3.1**; vertical mayor en 75/81 mediciones y más del doble en 54/81 |
| Borde medido primero, `ScanDown = 1` (72 mediciones, borde superior) | Mediana **+1.25**, frente a +0.23 en el borde final |
| Borde medido primero, `ScanDown = 0` (9 mediciones, borde inferior) | Mediana **+1.97**, frente a +0.41 en el borde final; mayor que el final en 8/9 |
| Cociente V/H por campaña | R1 5.3 · R2 3.1 · R3 1.8 |

## Conclusiones
- **Sigue al tiempo de medición, no a la muestra.** El borde elevado cambia de lado cuando cambia el sentido del barrido lento. Un gradiente de la muestra no haría eso.
- **Firma:** señal elevada en las primeras líneas medidas, que decae a lo largo del barrido. Encaja con el asentamiento del piezo o con la deriva térmica al inicio de cada medición. Además, cada medición tarda al menos ~43 min.
- **Orientación de la matriz confirmada:** tras `rot90`, con `ScanDown = 1` la fila 1 es la primera línea medida.

## Implicaciones (pendientes de decisión)
- **`I_seg`, binarización y descriptores morfológicos:** no se ven afectados. La corrección de fondo por línea resta un nivel por fila y elimina cualquier tendencia vertical.
- **`I_B`:** conserva la tendencia por diseño, porque RLOESS solo quita las rayas.
  - Los descriptores de **perfil** (pendiente, residuo y rango) miden sobre todo este artefacto.
  - Los de **intensidad** lo incluyen en parte.
- **Efecto de campaña:** la intensidad del artefacto difiere entre campañas, lo que puede contribuir al efecto de campaña en los descriptores de `I_B`.

## Opciones para la imagen eléctrica reconstruida `I_B` (pendiente de decisión)

**Construcción actual:**
1. Se resta el ajuste de crosstalk en la escala original.
2. Se aplica el filtro SyP 5×5.
3. Se calcula el perfil vertical p(i), la mediana de cada fila.
4. Se suaviza con RLOESS (50 filas) para obtener la tendencia p̃(i).
5. Se resta a cada fila solo la diferencia p(i) − p̃(i), es decir, las rayas.

La tendencia vertical se conserva a propósito, pero es instrumental (ver arriba).

**A. Dejar `I_B` como está y declararlo como limitación.**
- Sin recálculo.
- Los 3 descriptores de perfil miden el instrumento, y los 4 de intensidad lo incluyen en parte.

**B. Corregir también la tendencia y retirar los descriptores de perfil (recomendada).**
- Se resta a cada fila su nivel de fondo completo, con el mismo estimador de 3.1.3: la mediana del tercio menos intenso de la fila.
- El grupo «Perfil» desaparece y se recalculan los 4 descriptores de intensidad.
- Si hubiera un gradiente vertical real, también se elimina, porque no se puede separar de la deriva temporal.
- Decisión interna:
  - **(B1)** conservar el nivel global, con intensidades en escala nominal absoluta;
  - **(B2)** restar el fondo completo, de modo que las intensidades midan el contraste de la red sobre el polímero (cancela el desplazamiento de cada sesión, pero no el factor de escala).

**C. Corregir solo el transitorio inicial** (*creep* en las primeras líneas).
- Conserva más señal.
- Requiere definir el fin del transitorio en cada medición y no elimina la deriva del resto del barrido.

**Pendiente:** después de decidir, reescribir de forma explícita la narración de `I_B` en la Sección 3.1.7.
