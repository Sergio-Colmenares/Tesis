# Parámetros de adquisición y efecto de la campaña de medición

Fuentes: metadatos de los 81 `.ibw` (`resultados/adquisicion.csv`, extraídos de `D.WaveNotes`) y `resultados/descriptores.csv`.

## 1. Estructura de la adquisición

- Equipo: MFP-3D (Asylum Research), software 111111+1719 sobre Igor Pro 6.3.2.3.
- Área 60 × 60 µm, 1024 × 1024 puntos (paso 58.6 nm), ángulo 0°, lazo cerrado.
- Canal topográfico guardado **nivelado línea a línea** (primer orden: la media de cada línea es ≈ 0); canal eléctrico **sin nivelar** (`Planefit 4: None`).
- `Amp2InvOLS = 2e-08` en las 81 mediciones: la sensibilidad del 2.º armónico **no se calibró** (valor por defecto) → la amplitud eléctrica está en unidades nominales.
- **Cada réplica se midió en una sola sesión** (mismo cantiléver y calibración para sus 3 posiciones).
- **Cada número de réplica corresponde a una campaña de medición**, y cada campaña contiene una réplica de cada una de las 9 condiciones (diseño en bloques balanceado):

| Campaña | Fechas | Velocidad | Altura 2.ª pasada (media) |
|---|---|---|---|
| R1 (pos. 1–3) | 14–29 ene 2016 | 0.40–0.50 líneas/s | −10.7 nm |
| R2 (pos. 4–6) | 22 feb – 8 abr 2016 | 0.59–0.61 líneas/s | −15.2 nm |
| R3 (pos. 7–9) | 19–23 ene 2016 | 0.40 líneas/s | −19.9 nm |

- Excepciones: 0c-R2 y 2c-R2 con otro cantiléver (k ≈ 2.6 N/m, f₀ ≈ 68.8 kHz, AC 33 kHz → 2ω = 66 kHz); 0b-7 con 4 V en lugar de 3 V; 1c-1 medida en otra fecha.

## 2. ¿Cuánto explica cada factor la variación de los descriptores?

η² = fracción de la varianza explicada por la agrupación (nivel imagen, n = 81). Referencia bajo azar: ≈ 0.025 para 3 grupos (voltaje, frecuencia, campaña) y ≈ 0.33 para 27 grupos (réplica).

| Descriptor | Voltaje | Frecuencia | Campaña | Réplica |
|---|---|---|---|---|
| CNTD | 0.00 | 0.03 | **0.45** | 0.66 |
| CNTS | 0.02 | 0.02 | **0.22** | 0.62 |
| Intensidad media | 0.07 | 0.14 | 0.16 | **0.88** |
| Gradiente medio | 0.05 | 0.07 | 0.14 | 0.73 |
| Área media | 0.02 | 0.08 | 0.20 | 0.73 |
| Tortuosidad | 0.04 | 0.11 | **0.30** | 0.66 |
| Cobertura | 0.01 | 0.13 | 0.13 | 0.67 |
| Longitud de red | 0.02 | 0.15 | **0.31** | **0.88** |
| N.º de fragmentos | 0.03 | 0.02 | 0.07 | 0.64 |

**Prueba de permutación del efecto de campaña** (sobre las 27 medias por réplica, permutando las etiquetas de campaña dentro de cada condición, 5 000 permutaciones):

| Descriptor | η² | p |
|---|---|---|
| CNTD | 0.68 | 0.001 |
| Tortuosidad | 0.45 | < 0.001 |
| CNTS | 0.36 | 0.001 |
| Longitud de red | 0.35 | 0.002 |
| Área media | 0.28 | 0.04 |
| Gradiente medio | 0.19 | 0.007 |
| Intensidad media | 0.19 | 0.09 |
| Cobertura | 0.19 | 0.09 |
| N.º de fragmentos | 0.10 | 0.37 |

Medias por campaña: la campaña R3 (2.ª pasada más baja, −20 nm) da redes más cortas (730 frente a 1 037–1 158 µm), más fragmentadas, con CNTD mayor (0.105 frente a 0.088), áreas menores, tortuosidad menor e intensidad mayor (324 frente a ~253 unidades nominales).

El factor de transferencia estimado con un oscilador armónico ($V_{ac}^2\,G(2\omega/f_0)/k$, Q ≈ 148) **no se correlaciona** con la intensidad (ρ = −0.05), así que no sirve como corrección.

## 3. Interpretación

- El voltaje y la frecuencia de fabricación explican muy poca varianza (η² ≤ 0.15); la campaña de medición explica más en varios descriptores, **incluidos descriptores morfológicos**.
- La campaña puede reflejar diferencias de **adquisición** (altura de la 2.ª pasada, velocidad, cantiléver, sesión) o, si los números de réplica corresponden a lotes de fabricación, diferencias de **lote**. Con estos datos ambos efectos no se pueden separar.
- Como el diseño es balanceado (cada campaña incluye las 9 condiciones), el efecto de campaña se puede tratar como **bloque**: por ejemplo, estandarizando cada descriptor dentro de su campaña antes del análisis o incluyendo la campaña como factor.

## 4. Pendiente

- Confirmar si «réplica 1/2/3» corresponde también a lotes de fabricación.
- Decidir el tratamiento del efecto de campaña en la Sección 3.3 (análisis) y reportarlo en Resultados.
