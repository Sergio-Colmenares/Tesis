# Inventario de scripts (Anexos.rar + Codes.rar)

Referencia: `codigo/Descriptores_Final.m` (el pipeline de la tesis).

Para cada script se revisó si reproduce la misma cadena: crosstalk → SyP 5×5 → fondo → SyP 5×1 → P1–P99 → Otsu(6) ∧ local(σ=21) ∧ regional(σ=51), sensibilidad 0.55, `bwareaopen` 50, respaldo < 15 % con los mismos parámetros, cierre r = 3, `spur` 5, RLOESS 50, y $`E_B = E_{raw} - \hat E_T \cdot \mathrm{MAD}`$.

Leyenda: ✅ se queda · 🔧 se queda pero hay que corregirlo y volver a correrlo · ❌ se descarta

---

## Anexos.rar (versión reciente)

| Script | Qué hace | Produce en la tesis | Veredicto |
|---|---|---|---|
| `Descriptores_Final` | Pipeline + 20 descriptores | `descriptores.csv` (Cap. 4.2.4) | ✅ Idéntico al del repositorio |
| `Barrido_Validacion` | Barrido de 2688 configuraciones (sens, pmin, fallback, Otsu, σ_R, σ_L) y comparación Solo Local / Global+Local / Triple AND | Validación de parámetros y comparación con métodos alternativos (4.1.4) | ✅ Pipeline idéntico. Aquí está la definición de **FN = $`N_c`$ / cobertura** que pidió Alejo |
| `Barrido_Radio_Cierre` | Barrido de r = 1…10 | Tabla del radio (4.2.1) | 🔧 Mide el esqueleto como **nº de píxeles × Δ** (835 µm), no con la longitud ponderada con √2 del descriptor (975 µm) → discordancia #9 |
| `Barrido_Ventana_RLOESS` | Barrido de la ventana RLOESS | Tablas RLOESS (4.2.2) | 🔧 **Reconstruye $`E_B`$ con la fórmula vieja** (`+ median(Elec_Raw)`, línea 210), distinta de la del pipeline final. Las columnas Δ int. media y Δ int. P90 (%) cambian; pendiente, RMS, rango, std y gradiente no |
| `barrido_poda` | Barrido de la poda 0…10 | Tabla de poda (4.2.3) | ✅ Idéntico al pipeline; incluye control automático contra `descriptores.csv` |
| `comparar_paper_vs_pipeline` | CNTS con pipeline / método de [4] / umbral de [4] sobre $`E_{seg}`$ | Reproducibilidad (3.2.1 y 4.2.4) | ✅ Idéntico |
| `ExportarEtapas` | PDFs por etapa (81 imágenes), mosaicos 3×3 y `stats_etapas.csv` | Figuras `01_raw_2b` … `12_skel_2b` y tablas de 4.1 | 🔧 Usa el **respaldo viejo** (sens 0.5, pmin 100) en vez del estandarizado (0.55, 50). Tiene `fab_destacada = '1a'`, pero las figuras de la tesis son del set 2b. Solo afecta a la imagen que activa el respaldo |
| `Calcular_Percentil75` | En realidad es `Verificar_Documento`: compara los números del documento con los CSV y marca [OK]/[FAIL] | — (herramienta de control) | ✅ Muy útil; renombrar a `verificar_documento.m` |
| `diagnostico_orientacion` | Compara 3 formas de agregar la orientación y mide el sesgo de rejilla (`gridfrac`) | — | ✅ Es justo la prueba que necesita la discordancia #13 (orientación cerca de 0°/90°) |
| `barrido_orientacion` | Estabilidad de θ frente a σ_d y σ_i | — | ✅ Soporte para defender σ_d = 2, σ_i = 8 |
| `estabilidad_vs_coherencia` | Estabilidad de θ por imagen frente a la coherencia | — | ✅ Soporte para «θ solo es válido con coherencia alta» |
| `verificar_orientacion` | Visor interactivo σ_d = 2 vs 4 | — | ❌ Herramienta visual exploratoria |
| `ExportarGrids` | Mosaicos 3×3 por etapa | — | ❌ Duplicado de `ExportarEtapas`, y con el respaldo viejo |
| `Main_compara_tortuosidad` | Dos variantes de tortuosidad (diámetro vs «peel») | — | ❌ La decisión ya se tomó: el pipeline usa el diámetro geodésico |
| `corregidodesc` | Versión anterior de descriptores (opción KDE, tortuosidad por hilos simples) | — | ❌ Desactualizado |
| `Validacion_Visual_Descriptores` | Visor interactivo de los 20 descriptores | — | ❌ Usa $`E_B`$ con la fórmula vieja y el respaldo viejo |
| `IBWread`, `readIBWbinheader` | Lectura de `.ibw` | — | ✅ Necesarios (idénticos en ambos `.rar`) |
| `readIBWheaders.m` | Lectura de `.ibw` (la llama `IBWread`) | — | ⚠️ **No se pudo extraer**: el `.rar` está incompleto. Sin él, `IBWread` no funciona |
| `python_colormaps.mat`, `binarizacion_castaneda.mlx` | — | — | ⚠️ No se pudieron extraer (archivo vacío) |

## Codes.rar (versiones anteriores)

Casi todo usa parámetros viejos: sensibilidad 0.6 o 0.5, Otsu con 5 umbrales, ventanas 101/15, pmin 100.

| Script | Veredicto | Razón |
|---|---|---|
| `mosaicos_2b` | ✅ | Genera `mosaico_espacial/intensidad/forma/orientacion/conectividad/perfil.pdf` (Cap. 3.2) con el pipeline final idéntico |
| `ML_Clasificacion` | ❌ (reescribir) | Usa nombres de columnas viejos (`curvatura_media`, `area_media_nm2`, `cluster_perc_norm`…) que ya no existen en `descriptores.csv`. Además valida con `KFold` estratificado de 9 particiones, **no con GroupKFold por réplica** como describe la sección de ML: mezcla imágenes de la misma réplica entre entrenamiento y prueba |
| `Descriptores_Final` (versión de Codes), `descriptores` | ❌ | Versiones anteriores: unidades viejas, $`E_B`$ con `+ median` |
| `Main_EFM_v3`, `v6`, `v7`, `CINCOFEB`, `cuatrofeb`, `cieciseismar`, `QunceMar`, `intentos` | ❌ | Iteraciones anteriores del pipeline o del barrido |
| `Barrido_Global_Radios` | ❌ | Reemplazado por `Barrido_Radio_Cierre` |
| `Validacion_Preprocesamiento_Batch` | ❌ | Barrido de kernels de SyP que no aparece en la tesis |
| `Visor_Morfologia`, `Visor_ValidacionDesc`, `VisorOrientacionPCA`, `Visors` | ❌ | Visores exploratorios con parámetros viejos |
| `Main` (visor_Destriping), `I_A_M`, `I_A_MR`, `Manchas`, `rayones`, `rayoness`, `rayonesss`, `Comparar_Perfil` | ❌ | Pruebas de *destriping*, manchas y rayones que no llegaron al pipeline final |
| `Filtering`, `PlaneFit`, `VisualizationFig1b` | ❌ | Código inicial de nivelación (rutas del director) |
| `*.asv` | ❌ | Autoguardados de MATLAB |
| `Crosstalk_Results.csv/.mat`, `Stability_Results.csv/.mat` | ❌ | Salidas de scripts viejos. Dato interesante: `Crosstalk_Results` muestra una correlación con el **gradiente** topográfico (~0.13) mayor que con la altura (~0.01), lo que apoya la discordancia #8 |
| `generadorimagenes.mlx` | ⚠️ | No se pudo extraer. Puede ser el que genera las PNG del Marco Teórico (`1c-6_sh.png`, `0a-5_topo.png`…) |

---

## Correcciones necesarias en los scripts que se quedan

1. **`Barrido_Ventana_RLOESS.m`, línea 210**: quitar `+ med_raw` para que $`E_B`$ sea igual al del pipeline. Volver a correrlo y actualizar las columnas Δ int. media y Δ int. P90 de la tabla de estabilidad RLOESS.
2. **`Barrido_Radio_Cierre.m`**: calcular `skel_um` con la longitud ponderada (ortogonales 1, diagonales √2), igual que el descriptor. Volver a correrlo y actualizar la columna «Skel [µm]» y el texto de 4.2.1 (835 → ~975 µm para r = 3).
3. **`ExportarEtapas.m`**: respaldo con sensibilidad 0.55 y pmin 50; `fab_destacada = '2b'`. Agregar el $`R`$ múltiple del ajuste de crosstalk (#8).
4. **Todos**: cambiar las rutas `C:\Users\MSI\...` por rutas relativas al repositorio.
