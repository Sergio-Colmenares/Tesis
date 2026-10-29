# Fuentes y dependencias del trabajo

Registro de todo lo que usa la tesis y que no fue desarrollado en ella: código de terceros, software, datos y fuentes bibliográficas de los métodos. Sirve para armar las referencias y para la reproducibilidad. **Mantenerlo al día cada vez que se agregue algo.**

Estado: ✅ verificado · ⚠️ por verificar o completar · ❌ falta

---

## 1. Código de terceros incluido en el repositorio

| Archivo | Qué hace | Autor y fuente | Estado | Dónde se usa |
|---|---|---|---|---|
| `codigo/utils/IBWread.m` | Lee un archivo `.ibw` (Igor Binary Wave) y devuelve sus canales | Jakub Bialek, «Igor Pro file format (ibw) to matlab variable», MATLAB Central File Exchange, entrada 42679. https://www.mathworks.com/matlabcentral/fileexchange/42679-igor-pro-file-format-ibw-to-matlab-variable | ⚠️ Confirmar año y versión en la página (la búsqueda muestra v1.0.0.0, actualizada en 2013, pero la cita sugerida da 2024). Confirmar que los archivos se descargaron de ahí. | Lectura de los 81 `.ibw` (Sección 3.1; todos los scripts) |
| `codigo/utils/readIBWheaders.m` | Lee los encabezados del archivo (llamada por `IBWread`) | Mismo paquete | ⚠️ Igual que arriba | — |
| `codigo/utils/readIBWbinheader.m` | Lee el encabezado binario (llamada por `readIBWheaders`) | Mismo paquete | ⚠️ Igual que arriba | — |
| `codigo/utils/python_colormaps.mat` | Mapa de color viridis (`cmap_viridis`) para todas las figuras | Viridis: S. van der Walt y N. Smith, mapa de color de Matplotlib. El `.mat` se creó el 11-06-2025 en un sistema posix, al parecer exportado desde Python. | ⚠️ Registrar quién lo generó y cómo, y citar el origen del mapa. | Todas las figuras con mapas |

**Licencia:** ❌ el repositorio redistribuye estos archivos sin aviso de licencia. Verificar en la página de File Exchange qué licencia tiene el paquete (suelen ser BSD, que exige conservar el aviso), agregarla como `codigo/utils/LICENSE_IBWread.txt` y citar la fuente en el encabezado de `IBWread.m`.

## 2. Software

| Software | Versión | Uso | Estado |
|---|---|---|---|
| MATLAB | R2025b | Todo el procesamiento, los descriptores y las figuras | ✅ |
| Image Processing Toolbox | la de R2025b | `adaptthresh`, `imbinarize`, `multithresh`, `bwareaopen`, `imclose`, `strel`, `bwskel`, `bwmorph`, `regionprops`, `bwconncomp`, `bwlabel`, `bwdistgeodesic`, `imgaussfilt`, `medfilt2`, `adapthisteq`, `mat2gray` | ✅ |
| Statistics and Machine Learning Toolbox | la de R2025b | `mad`, `prctile`, `fitdist` | ✅ |
| Parallel Computing Toolbox | la de R2025b | Solo `parfor` en los barridos (opcional) | ✅ |
| Funciones base de MATLAB | — | `gradient`, `rot90`, operador `\` (mínimos cuadrados por QR), `randi` y `rng`, `smoothdata` (solo en la reconstrucción de E_B, ya retirada) | ✅ |
| Igor Pro / software del MFP-3D (Asylum Research) | ⚠️ | Adquisición y nivelado de primer orden de la topografía | ⚠️ Registrar versión del software de adquisición |
| Análisis exploratorio (correlación, agrupamiento, PCA; Sección 3.3) | ❌ | — | ❌ El código no está en el repositorio: registrar con qué se hizo (MATLAB, Python…) y agregarlo |
| LaTeX (pdflatex, TikZ, pgfplots) | — | Documento y diagrama de la metodología | ✅ |

## 3. Datos

| Datos | Origen | Estado |
|---|---|---|
| 81 mediciones EFM-2ω (`.ibw`), microscopio MFP-3D (Asylum Research) | ⚠️ Registrar quién las adquirió, cuándo (campañas R1–R3, ver `tendencia_vertical.csv`) y si son las mismas muestras de [4] | ⚠️ |
| Muestras SWCNT/poliimida, 9 condiciones de fabricación (5/10/15 V × 10 Hz/1 kHz/100 kHz) | Fabricación descrita en [4] | ⚠️ Confirmar |
| Eficacia de apantallamiento (parámetros S) | ⚠️ Registrar origen, equipo (VNA) y formato | ❌ Aún no está en el repositorio |

Los `.ibw` no se suben al repositorio (`datos/crudos/`, ver `codigo/README.md`).

## 4. Fuentes de los métodos (Cap. 3)

Referencias según la numeración actual de `09_referencias.tex` (cambiará al ordenar y agregar las faltantes).

| Método | Sección | Fuente | Estado |
|---|---|---|---|
| Canal eléctrico EFM-2ω ∝ ∂C/∂z | 3.1 | [5] Castañeda-Uribe et al., 2015 | ✅ |
| Condiciones de fabricación | 3.1 | [4] Castañeda-Uribe y Avila, 2020 | ✅ |
| Lectura de `.ibw` | 3.1 | Bialek (File Exchange) | ❌ Falta en las referencias (marcador «[ref. pendiente]») |
| Terminología de procesamiento de imágenes; filtro de mediana; umbralización adaptativa; morfología; momentos de segundo orden; tensor de estructura | 3.1, 3.2 | [6] Gonzalez y Woods, 2017 | ⚠️ Verificar que el tensor de estructura esté en [6]; si no, buscar una fuente específica |
| Crosstalk topográfico; desplazamientos entre líneas de barrido | 3.1.1, 3.1.3 | [8] Klapetek, 2018 | ✅ |
| Estimador robusto σ = med(|R|)/0.6745 | 3.1.2 | — | ❌ Sin cita (estimador MAD de la desviación estándar; p. ej. Hampel o Rousseeuw y Croux) |
| Método de Otsu multinivel | 3.1.6 | [9] Otsu, 1979 | ✅ (la extensión multinivel de `multithresh` podría citarse aparte) |
| Corrección de fondo por línea (percentil adaptativo) | 3.1.3 | Desarrollo propio | ✅ |
| Esqueletización (`bwskel`) y poda | 3.1.7 | — | ⚠️ Sin cita; `bwskel` se basa en Lee, Kashyap y Chu (1994) según la documentación de MATLAB |
| Descriptores CNTD, CNTA, CNTS; ajuste lognormal; α = 2000 nm | 3.2.1 | [4] | ✅ |
| Método de binarización de [4] (CLAHE, mediana, 75 % del máximo) | 3.2.1 | [4]; CLAHE: Zuiderveld (1994) | ⚠️ CLAHE sin cita propia |
| Distancia geodésica cuasi-euclidiana | 3.2.2 | — | ⚠️ Sin cita |
| Análisis exploratorio y modelos | 3.3 | [7] Hastie et al., 2009 | ✅ |

## 5. Referencias del documento sin citar

| Referencia | Estado |
|---|---|
| [11] Silverman, 1986 | ❌ No se cita en ningún capítulo (la pauta prohíbe incluir referencias no citadas) |
