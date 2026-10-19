# Corrección de crosstalk topográfico: resumen de la discusión

## Método actual
Modelo lineal global por medición: $\tilde E = \beta_0 + \beta_1\tilde T + \beta_2\,\partial\tilde T/\partial x + \beta_3\,\partial\tilde T/\partial y$, ajustado por mínimos cuadrados con los $1024^2$ puntos; se resta el mapa ajustado al canal eléctrico normalizado.

## Hechos establecidos
1. **La topografía llega nivelada solo en primer orden.** El software resta a cada línea su recta (desnivel e inclinación), pero no su curvatura. La curvatura del escáner (*scanner bow*) persiste: **mediana del 66 %** de la varianza de la topografía (> 50 % en 54/81 mediciones, > 90 % en 21).
2. **La curvatura no es relieve real.** En modo Nap la punta sigue la trayectoria de la primera pasada, así que la curvatura no cambia la distancia punta–muestra y no debería generar crosstalk.
3. **El término de altura ($\beta_1$) se contamina con la curvatura.** Al quitarla, $\beta_1$ cambia de signo en 23/81 mediciones y cambia más de 0.1 en 34/81. Esto ocurre sobre todo en mediciones con **poco crosstalk y mucha curvatura** (correlación de rangos entre curvatura y R²: −0.34).
4. **En las mediciones con crosstalk real, el modelo es consistente.** En las 10 de mayor R², $\beta_1$ (sin curvatura) es siempre negativo y de tamaño similar, y el coeficiente de pendiente casi no cambia al quitar la curvatura (p. ej. `0a-5`: $\beta_{\partial x}$ −0.88 → −0.87). Quitar la curvatura vuelve consistente $\beta_1$ (p. ej. `2c-6`: +0.04 → −0.24).
5. **La corrección actual inyecta una leve curvatura** en el canal eléctrico: mediana del 3 % de su variación (> 5 % en 23 mediciones, > 10 % en 5: `0a-6`, `0b-6`, `1a-9`, `1c-1`, `1c-5`).
6. **El R² global es pequeño** (mediana 0.5 %, máximo 7.7 %) y **no mide la calidad de la corrección**: las huellas topográficas ocupan poca área y el R² depende de cuánto otro ruido tenga la imagen (p. ej., las bandas horizontales de `0a-4` lo reducen aunque la corrección funcione).

## Evidencia visual
- **`0a-5`** (crosstalk más fuerte de las 81, R² 7.7 %, curvatura 16 %): los rayones diagonales casi desaparecen; los CNTs quedan intactos.
- **`0a-4`** (misma sesión, mismos coeficientes, R² 2.2 %): se eliminan las estelas de puntos y el contraste ancho de los rayones; quedan dos líneas finas paralelas en el rayón principal, algunas partículas puntuales y rayones finos sin huella topográfica. La impresión de peor resultado se debe sobre todo a **artefactos horizontales de barrido**, que no son crosstalk y se tratan en etapas posteriores.

## Conclusiones
1. La corrección **funciona** donde hay crosstalk real; su efecto visible viene de los términos de pendiente y de altura.
2. La curvatura del escáner **no daña la corrección donde importa**, pero vuelve inconsistente el término de altura en las mediciones con poco crosstalk e introduce una leve curvatura en el canal eléctrico.
3. Quitar la curvatura de la topografía antes del ajuste **no cambia el comportamiento donde la corrección es visible**; hace que el modelo signifique lo mismo en las 81 mediciones.
4. **Limitación del método lineal global:** no elimina el crosstalk local o no lineal (bordes residuales de rayones, partículas, rayones sin huella topográfica).
5. **Para la tesis:** la evidencia correcta es visual y local (pares `0a-5` y `0a-4`), no la correlación posterior (≈ 10⁻¹⁶ por construcción) ni el R² global.

## Decisión: se mantiene la corrección actual
Se evaluó quitar a la topografía su perfil medio a lo largo de la línea, $T_l = \tilde T - \overline{\tilde T}_{\text{col}}$, antes del ajuste.

- **Donde la corrección es visible no cambia nada:** `0a-5`: $\beta_{\partial x}$ −0.88 → −0.87.
- **Cambia la entrada de una binarización sensible a cambios globales.** En `0a-2`, la diferencia entre versiones fue de ±0.2 MAD, toda en el término de altura (las pendientes no aportan), pero bajó el primer umbral de Otsu de 0.126 a 0.078 y creó una mancha sobre una zona identificada como fondo.
- **La curvatura inyectada no tiene consecuencias visibles:** en las 5 mediciones con más curvatura inyectada (`0a-6`, `0b-6`, `1a-9`, `1c-1`, `1c-5`), las máscaras finales no muestran la curva.

**Para la Sección 3.1.1:**
- El modelo es empírico y sus coeficientes no se interpretan físicamente.
- Declarar como limitación la curvatura residual de la topografía (nivelado de primer orden) y su efecto en $\beta_1$ y en el canal eléctrico (mediana 3 %), indicando que no se observan consecuencias en las máscaras.
- La validación es visual sobre los casos con crosstalk fuerte (`0a-5`, `0a-4`).

## Efecto de la limitación sobre los descriptores (81 mediciones)
Se calcularon los 20 descriptores con la corrección actual y con la topografía sin curvatura. Las diferencias se expresan en unidades de la desviación estándar dentro de condición, $s_w$ (combinada de las 9 imágenes de cada una de las 9 condiciones).

- **Intensidad y perfil:** el efecto es despreciable. La mediana del cambio está entre $0.002$ y $0.006\,s_w$ y el máximo es $\le 0.15\,s_w$.
- **Morfológicos:**
  - **No hay sesgo.** Por ejemplo, la tortuosidad sube en 42 de 81 mediciones, con un cambio mediano de $0.004$.
  - **Pero hay sensibilidad.** La mediana del cambio va de $0.05$ a $0.34\,s_w$, y el P90 llega a $\approx 1\,s_w$ (tortuosidad $0.96$; CNTA $0.63$).
  - **Cobertura:** cambio mediano de 0.1 puntos porcentuales, con un máximo de 1.6.
- **Máximos que no indican un efecto real:**
  - el de orientación en `0a-6` es un artefacto de la diferencia lineal entre ángulos: 1.8° frente a 177.4° son en realidad 4.4° de diferencia;
  - el de elongación media en `1c-1` (3.06 → 2.02) refleja que esa media depende de unas pocas componentes muy alargadas.
- **Interpretación:**
  - la limitación no sesga los descriptores;
  - lo que mide la prueba es la **sensibilidad de los descriptores morfológicos a una perturbación pequeña de la entrada**, que viene de la binarización (umbral global) y no del crosstalk.

## Observación lateral: papel real de $M_G$ (no se modifica)
Pipeline actual, 81 mediciones:

- $M_G$ deja pasar el **46–98 %** de la imagen (mediana 73.8 %), frente a una cobertura final de ~22 %. La excepción es `0a-9` (19.4 %), el caso del respaldo.
- La primera clase de Otsu es el fondo más oscuro (mediana 26 % de la imagen), no todo el fondo. Su papel real es **excluir el fondo oscuro heterogéneo** (Solo Local 0.272 → Global+Local 0.256 de cobertura).
- La red la definen sobre todo los umbrales adaptativos.
- **Pendiente de redacción (no de método):** la frase de la metodología «la primera clase, asociada al fondo polimérico, se descarta» debe describir este papel.
- **Alternativas exploradas y descartadas:**
  - barrera de significancia con fondo local (demasiado laxa: detecta la banda de `0a-2`);
  - barrera global $m + k s$ (elimina detección);
  - separación por forma (inviable por la deformación con la profundidad).

## Párrafo retirado de la Metodología (3.1.1), pendiente de ubicar en Resultados
Se retiró del documento porque es un resultado del desarrollo y no parte de la metodología. Texto LaTeX original:

```latex
El modelo es empírico: su objetivo es eliminar las huellas topográficas del canal eléctrico, y sus coeficientes no se interpretan físicamente. Como el canal topográfico solo está nivelado en primer orden, conserva la curvatura del barrido del escáner a lo largo de cada línea, que no corresponde al relieve de la muestra; en la segunda pasada de la medición EFM-2$\omega$ (Capítulo 2) la punta sigue la trayectoria registrada en la primera, por lo que esta curvatura no modifica la distancia punta--muestra ni genera crosstalk. Sin embargo, la curvatura entra al término de altura del modelo: en las mediciones con poco crosstalk vuelve inconsistente el coeficiente $\beta_1$ e introduce en el canal eléctrico una curvatura leve (mediana del 3~\% de su variación). Esta curvatura inyectada se cuantificó como la desviación estándar de la diferencia entre el canal corregido con la topografía original y el corregido con la topografía sin su perfil medio a lo largo de la línea, $\tilde T(i,j) - \frac{1}{N}\sum_{m=1}^{N} \tilde T(m,j)$, dividida por la desviación estándar de $\tilde I$. Para evaluar su efecto, los descriptores (Sección~\ref{sec:met_descriptores}) se recalcularon con esta segunda versión de la corrección, y cada cambio se expresó en unidades de $\sigma_{cond}$, la desviación estándar del descriptor entre las nueve mediciones de una misma condición de fabricación, combinada sobre las nueve condiciones ($\sigma_{cond}^2$ es el promedio de las nueve varianzas). Los cambios no presentan un sesgo sistemático; en los descriptores de intensidad son inferiores a $0.15\,\sigma_{cond}$, y en los morfológicos reflejan principalmente la sensibilidad de la binarización (Sección~\ref{sec:met_binarizacion}). Con base en estos resultados, se conserva el modelo descrito.
```
