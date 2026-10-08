# Métricas de validación del pipeline

Inventario de todas las métricas que usan los scripts de `codigo/validacion/`, `codigo/figuras/ExportarEtapas.m` y `codigo/orientacion/`. Para cada una se indica la definición, qué valor se busca y dónde aparece en la tesis.

Notación: $M$ es una máscara binaria de $N\times N$ píxeles, y $N_c(M)$ es su número de componentes conexas (vecindad 8).

> **Advertencia general.** Ninguna de estas métricas compara contra una «verdad» anotada a mano. Todas miden **consistencia interna**: estabilidad frente a los parámetros, dispersión entre imágenes y efecto de cada etapa. Por eso no pueden decir si la binarización «acierta» (comentario de Alejo, pág. 46). Para eso haría falta un subconjunto de imágenes con la red marcada a mano, o imágenes sintéticas con red conocida.

---

## 1. Preprocesamiento (Cap. 4.1.1–4.1.3)
Scripts: `Barrido_Validacion` (`preprocesamiento55.csv`) y `ExportarEtapas` (`stats_etapas.csv`).

| Métrica | Definición | Qué se busca | Tabla |
|---|---|---|---|
| Correlación eléctrico–topográfica antes | $r(\tilde E, \tilde T)$, Pearson | Mide cuánto crosstalk hay; reportar $\lvert r\rvert$ | `tab:crosstalk_2b` |
| Correlación después | $r(E_{corr}, \tilde T)$, igual con $\partial_x T$ y $\partial_y T$ | ≈ 0 **por construcción** (residuo de mínimos cuadrados), no prueba nada | texto |
| $R$ múltiple del crosstalk *(nuevo)* | $R=\sqrt{1-\lVert E_{corr}\rVert^2/\lVert\tilde E-\bar{\tilde E}\rVert^2}$ | Fracción de la variación del canal eléctrico explicada por la topografía (altura + pendientes). Es la métrica correcta del efecto de la corrección | por agregar |
| % píxeles SyP 1 y SyP 2 | $100\cdot\#\{R>n\hat\sigma\}/N^2$ | Pequeño en SyP 1 (solo *outliers*); mayor en SyP 2 si hay líneas | `tab:impulsivo_2b` |
| Varianza entre filas antes / después | $\mathrm{var}_i\big(\overline{E(i,\cdot)}\big)$, varianza de las medias por fila | Debe **bajar** tras la corrección de fondo: las filas quedan al mismo nivel | `tab:artefactos_2b` |
| Ruido residual por etapa | desviación estándar de la imagen tras cada etapa | Debe disminuir etapa a etapa | solo en CSV |

## 2. Binarización: barrido de parámetros (Cap. 4.1.4)
Script: `Barrido_Validacion` (`barrido_binarizacion55.csv`). 1 344 configuraciones = 7 sensibilidades × 4 $p_{\min}$ × 4 Otsu × 3 σ regional × 4 σ local, con respaldo 15 %, sobre 81 imágenes.

| Métrica | Definición | Qué se busca |
|---|---|---|
| **Cobertura** | $c = \lvert M_e\rvert / N^2$, fracción de la imagen marcada como CNT | Intermedia: ni sub- ni sobredetección. En la configuración elegida, ≈ 22 % |
| **Número de componentes** $N_c$ | componentes conexas de $M_e$ | Interpretable solo junto con la cobertura |
| **Fragmentación normalizada FN** | $\mathrm{FN} = N_c / c$, componentes por unidad de cobertura | **Menor = red menos fragmentada** para la misma cantidad de material detectado. Separa «más piezas» de «más material» |
| **CV de cobertura, $N_c$ o FN** | $\mathrm{CV} = s/\bar x$ entre las 81 imágenes | **Menor = más estable**: el mismo pipeline se comporta parecido en todas las imágenes |
| Cuartiles de FN ($Q_1$, mediana, $Q_3$) | sobre las 1 344 configuraciones | Ubicar la configuración elegida dentro del espacio de configuraciones |
| Respaldo activado | 1 si $c(M_L\wedge M_G\wedge M_R) < 0.15$ | Que se active muy pocas veces (1 de 81) |
| Cobertura mínima | mínimo de $c$ entre las 81 | Que ninguna imagen quede casi vacía |

**Criterio de elección que se deduce del texto:** cobertura intermedia + CV de cobertura mínimo + FN baja (entre $Q_1$ y la mediana). **Hay que escribirlo explícitamente**: es la pregunta de Alejo de si se maximiza, minimiza o balancea.

**Comparación de métodos** (Solo Local / Global+Local / Triple AND / Pipeline): las mismas métricas, más el tamaño medio de componente $= c\,N^2/N_c$.

## 3. Representaciones de trabajo (Cap. 4.2)

### Radio del cierre — `Barrido_Radio_Cierre` (r = 1…10)
| Métrica | Definición | Qué se busca |
|---|---|---|
| Material agregado | $\Delta c = c(M_{mor}) - c(M_e)$ | Pequeño: el cierre no debe inventar material |
| Componentes fusionadas | $\Delta N_c = N_c(M_e) - N_c(M_{mor})$ | Que se unan las discontinuidades reales sin fusionar regiones separadas |
| Derivadas $d(\Delta c)/dr$, $d(\Delta N_c)/dr$ | diferencias entre radios consecutivos | **Codo**: el radio donde dejan de bajar y rebotan (r = 3 → 4) |
| Índice de percolación | $\max_k\lvert C_k\rvert/\sum_k\lvert C_k\rvert$ | Que no salte (un salto indica conexiones artificiales) |
| Longitud del esqueleto | (corregida: pondera las diagonales con √2) | Que se estabilice |

### Ventana RLOESS — `Barrido_Ventana_RLOESS` (v = 10…300)
| Métrica | Qué se busca |
|---|---|
| Pendiente residual del perfil de $E_B$ | ≈ 0 (invariante por construcción) |
| RMS de las rayas $\sqrt{\overline{\delta^2}}$ y rango de la tendencia | Equilibrio: v pequeño sobrecorrige, v grande no corrige |
| Δ % de intensidad media, desv. est., P90 y gradiente frente a v = 50 | **Menor = descriptores robustos** a la elección de v |

### Poda del esqueleto — `barrido_poda` (0…10 iteraciones)
Tortuosidad media, longitud de red, nº de píxeles del esqueleto y nº de extremos. Se busca que los descriptores cambien poco. Resultado: la tortuosidad es casi invariante; la longitud decrece sin codo.

## 4. Reproducibilidad frente a [4] (Cap. 4.2.4)
Script: `comparar_paper_vs_pipeline`.

| Métrica | Definición |
|---|---|
| % máscaras válidas | imágenes con más de 10 espaciados para ajustar la lognormal (pipeline 81/81; método de [4] 31/81) |
| CNTS por voltaje a 10 Hz | media ± error estándar sobre las réplicas, para los tres métodos |
| Correlación de Spearman $\rho$ (CNTS vs. voltaje) | ¿se reproduce la tendencia decreciente de [4]? (ningún método la reproduce) |

## 5. Orientación (no está en la tesis todavía)
Scripts de `codigo/orientacion/`.

| Métrica | Definición | Qué se busca |
|---|---|---|
| $R$ dentro de réplica | $\lvert\tfrac13\sum e^{i2\theta_j}\rvert$ promediado sobre las 27 réplicas | Mayor que el azar (≈ 0.52): las 3 imágenes de una réplica comparten orientación. Valor en (2, 8): 0.675 |
| Desplazamiento angular | mediana de $\lvert\Delta\theta\rvert$ circular frente a $(\sigma_d,\sigma_i)=(2,8)$ | Pequeño: θ estable frente a los parámetros |
| Fracción en la rejilla (`gridfrac`) | fracción de componentes con θ a ±15° de 0°/90°/180° | ≈ 1/3 si no hay sesgo (60° de 180°); mucho más indica sesgo de rejilla |

## 6. Aprendizaje automático (pendiente)
La sección de ML está comentada en la tesis. Lo planteado allí: **exactitud**, **F1 macro**, **matriz de confusión** e **importancia por permutación**, con **GroupKFold por réplica**. Para la regresión hacia SE faltan por definir, por ejemplo: $R^2$ y RMSE con validación cruzada agrupada.
