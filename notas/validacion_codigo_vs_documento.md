# Validación: `codigo/Descriptores_Final.m` vs. documento (Cap. 3 Metodología)

Revisión etapa por etapa del código contra lo que describe la tesis
(`documento/capitulos/03_metodologia.tex` y los parámetros citados en
`04_resultados.tex`). No se ejecutó MATLAB; lo marcado como «verificar en MATLAB»
depende del comportamiento interno de una función de toolbox.

Leyenda: ✅ coincide · ⚠️ coincide pero el documento debe precisarlo · ❌ discrepancia

---

## Resumen de discrepancias (prioridad)

| # | Etapa | Problema | Qué cambiar |
|---|---|---|---|
| 1 | Binarización local/regional | La ecuación (3.x) `E > μ_G(1−α_s)` no es lo que hace `adaptthresh`. Con sensibilidad 0.55 la ecuación del documento da umbral 0.45·μ_G; `adaptthresh` (polaridad `bright`) escala la media local por `0.6 + (1 − s)` = **1.05·μ_G** | Verificar en MATLAB y corregir la ecuación del documento |
| 2 | Otsu multiclase | `multithresh(Eseg, 6)` devuelve **6 umbrales → 7 clases**. El documento y resultados dicen «6 clases en Otsu» | Decir «6 umbrales (7 clases)», o usar `multithresh(Eseg,5)` si la intención eran 6 clases (cambia resultados) |
| 3 | Corrección de fondo | El percentil adaptativo real es `p = 40 − 20ρ`, acotado a [25, 45]. Como ρ ≥ 0, **p nunca supera 40** y en la práctica queda entre ~32 % y ~39 %; las cotas 25/45 nunca se activan. Además p no crece con la homogeneidad como dice el texto (una fila gaussiana da ~36 %, una fila con 20 % de CNTs da ~38 %) | Escribir la fórmula real en el documento y describir el rango efectivo, o rediseñar la regla si la intención era otra |
| 4 | Perfil de gradiente | Por construcción, el perfil (mediana por fila) de `E_B` **es exactamente la tendencia RLOESS**: `E_B` se obtiene restando a cada fila `perfil − tendencia`. «Ruido RMS horizontal» no mide ruido, mide cuánto se aparta la tendencia suavizada de una recta | Decirlo explícitamente en 3.2.6 y renombrar el descriptor (p. ej. «no linealidad del perfil») |
| 5 | CNTA, umbral α | El documento dice α = 2000 nm «≈ longitud de **dos** SWCNTs»; el código dice «longitud máxima de **un** SWCNT individual» | Unificar con lo que dice [4] |
| 6 | Filtro 5×1 | En MATLAB `[5 1]` = 5 filas × 1 columna, es decir un kernel **vertical**. Es correcto para eliminar líneas horizontales (compara cada píxel con las filas vecinas), pero el documento no lo aclara | Escribir «kernel vertical 5×1 (5 filas)» y explicar por qué elimina líneas horizontales — responde además el comentario del director |

Puntos menores al final del documento.

---

## Etapa por etapa

### Lectura de datos
- ✅ Canal eléctrico = canal 5, topográfico = canal 1, 1024×1024 px, 60 µm → 58.59 nm/px.
- ⚠️ Se aplica `rot90` a ambos canales; afecta la convención de la orientación (ver Orientación).
- ⚠️ El comentario del código dice `AmpInvOLS`; resultados dice `Amp2InvOLS`. Unificar.

### 3.1.1 Corrección de crosstalk — ✅
- Modelo `E = β0 + β1·T + β2·∂T/∂x + β3·∂T/∂y` por mínimos cuadrados (`X \ E`) ✅.
- **El ajuste es global sobre toda la imagen** (una sola β por imagen) y se resta el mapa ajustado completo, no una constante ni un valor por fila. → Responde la pregunta del director en la pág. 22.
- ⚠️ La normalización es robusta: `(x − mediana)/MAD`. El documento solo dice «normalizadas»; conviene escribirlo.
- Nota: `[Gy, Gx] = gradient(Topo_norm)` tiene los nombres invertidos (`gradient` devuelve primero d/dx). **No afecta el resultado** porque ambos entran a la regresión.

### 3.1.2 Filtro de ruido impulsivo — ✅
- `M = medfilt2(I, kernel)`, `R = |I − M|`, `σ = median(R)/0.6745`, reemplazo donde `R > nσ` ✅ idéntico a las ecuaciones.
- Instancias: 5×5 con n = 3 tras el crosstalk; 5×1 con n = 2 tras la corrección de fondo ✅.
- ⚠️ 0.6745 es el cuantil 75 % de la normal estándar: hace que la MAD sea un estimador consistente de σ para ruido gaussiano. Falta explicarlo (pregunta del director).
- ⚠️ Ver discrepancia #6 (orientación del kernel 5×1).
- Menor: `medfilt2` rellena los bordes con ceros. Sobre `E_B` (escala original, valores ~250 pm ≠ 0) las esquinas de la imagen quedan reemplazadas por 0. Efecto despreciable en descriptores, pero se evita con `medfilt2(I, k, 'symmetric')`.

### 3.1.3 Corrección de fondo — ⚠️/❌
- Para cada fila: ρ = MAD/(P95 − P5) ✅, se toman los píxeles por debajo del percentil p y se resta su mediana ✅.
- ❌ Ver discrepancia #3. La regla `p = 40 − 20ρ` no aparece en el documento y su comportamiento no coincide con la explicación.
- Orden real del pipeline: crosstalk → SyP 5×5 → fondo → SyP 5×1 → normalización P1–P99. Es el orden que pide el director; el documento debe presentarlo así.

### Normalización P1–P99 — ✅
Idéntica a la ecuación del documento (recorte a [0, 1]).

### 3.1.4 Binarización
- **Local** (21 px) y **regional** (51 px), estadístico gaussiano, sensibilidad 0.55 ✅ en parámetros.
  - ❌ Ver discrepancia #1. **Verificar en MATLAB:**
    ```matlab
    T = adaptthresh(0.5*ones(64), 0.55, 'Statistic','gaussian', 'ForegroundPolarity','bright');
    T(32,32)   % 0.525 → factor 1.05 = 0.6+(1−s);  0.225 → factor (1−s) como dice el documento
    ```
    También puedes ver la fórmula con `edit adaptthresh`.
  - ⚠️ El σ del núcleo gaussiano lo define internamente `adaptthresh` a partir del tamaño de ventana; el documento no lo dice.
- **Global**: ❌ ver discrepancia #2. «La primera clase se descarta» ✅ (`Eseg >= thresh(1)`).
  - ⚠️ El documento la describe como «análisis multiescala»; `multithresh` es Otsu **multinivel**, no multiescala.
  - El `bwareaopen` aplicado a `BW1` antes de la intersección no está en el documento, pero es redundante: no cambia el resultado final.
- **Integración** `M_L ∧ M_G ∧ M_R` + componentes ≥ 50 px ✅.
- **Respaldo**: si cobertura < 15 % → binarización local + `bwareaopen(…, 50)` ✅. Los valores 0.55 y 50 están escritos a mano en vez de usar `sensibilidad` y `pix_minimos`; hoy coinciden.

### 3.1.5 Representaciones de trabajo — ✅
- `M_e = BW2`, `M_mor = imclose(BW2, strel('disk',3))` ✅.
- Esqueleto `bwskel` + `bwmorph('spur',5)` ✅.
- `E_B = E_raw − E_fit·MAD` deshace correctamente la normalización ✅; luego SyP 5×5 y corrección RLOESS de ventana 50 ✅. `E_B` **no** pasa por la corrección de fondo ni por el filtro 5×1 (coherente con el documento).

### 3.2.1 Distribución espacial — ✅
- 100 líneas horizontales con semilla fija (`rng(42)`, mismas filas para todas las imágenes) sobre `M_mor` ✅.
- Ajuste lognormal; η = moda = exp(μ − σ²) ✅; CNTD = F(1.2η) − F(0.8η) ✅; CNTA = 1 − F(α) ✅; CNTS = CNTA/CNTD ✅.
- ⚠️ No documentado: (a) si hay ≤ 10 medidas el descriptor es NaN; (b) los espaciados en los bordes de la línea se descartan pero los tramos de CNT que tocan el borde sí se cuentan (truncados); (c) las filas se sortean con reemplazo (pueden repetirse).
- ❌ Ver discrepancia #5.

### 3.2.2 Intensidad — ✅
- Media, desviación estándar y P90 de `E_B` sobre `M_e`, en pm ✅.
- Gradiente medio: `|∇E_B|` promediado sobre `M_e`, ×10¹²/58.6 → pm/nm ✅. (`gradient` usa diferencias centrales; nombres Gx/Gy invertidos, sin efecto en la magnitud.)

### 3.2.3 Morfología — ✅
- `regionprops` sobre `M_mor`; elongación = media(eje mayor/eje menor) ✅ (el cociente es el mismo con ejes o semiejes).
- Área media y desviación en µm² ✅.
- Tortuosidad: arco geodésico (diagonales √2) / cuerda euclidiana entre los extremos más alejados, promediado por componente ✅.
- ⚠️ No documentado: se descartan componentes con < 8 px, con menos de 2 extremos (lazos cerrados) o con arco < 15 px; M es el número de componentes **retenidas**. El par de extremos se busca con doble barrido, que es exacto en árboles y aproximado si el esqueleto tiene ciclos.

### 3.2.4 Orientación — ✅
- σ_d = 2 px, σ_i = 8 px, tensor de estructura, λ₁, λ₂, coherencia y corrección de 90° ✅ (aquí sí `[Gx, Gy]` está en el orden correcto).
- ⚠️ El tensor se suma **solo sobre los píxeles de `M_mor`**; el documento debería decirlo.
- ⚠️ Convención del ángulo: el eje y de la imagen apunta hacia abajo, así que los ángulos crecen en sentido horario, y además las imágenes están rotadas con `rot90`. Indicar la convención si se interpreta la orientación respecto a la dirección de barrido.

### 3.2.5 Conectividad — ✅
- Cobertura sobre `M_e` ✅ (esto responde la pregunta del director: es sobre la estricta por definición del descriptor).
- Índice de percolación y número de fragmentos sobre `M_mor` (conectividad 8) ✅.
- Longitud de red: pasos ortogonales (1) y diagonales (√2), excluyendo diagonales que ya tienen un camino ortogonal ✅. Esta exclusión podría mencionarse.

### 3.2.6 Perfil de gradiente — ⚠️
- Pendiente (×10¹²/58.6 → pm/nm), RMS del residuo y rango ✅ en cálculo.
- ❌ Ver discrepancia #4.

### Recuento
20 descriptores en el CSV ✅ (3 + 4 + 4 + 2 + 4 + 3).

---

## Puntos menores
- Cada imagen se procesa dentro de `try/catch`: si una falla, solo se imprime un mensaje y el CSV queda con menos filas. Comprobar que el CSV tenga 81 filas.
- Rutas absolutas (`C:\Users\MSI\...`) y dependencias no incluidas (`IBWread`, `python_colormaps.mat`).
- El colormap se carga pero no se usa.
- No incluido en esta revisión: correlación, PCA y modelos de ML (no están en este script).
