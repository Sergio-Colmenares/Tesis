# Metodología detallada: formulación matemática del pipeline

Descripción completa, etapa por etapa, de lo que calcula `codigo/Descriptores_Final.m`.
Usa la notación de la tesis ($E$, $T$, $E_{seg}$, $M_L$, $M_G$, $M_R$, $M_e$, $M_{mor}$, $E_B$)
y está pensada como base para reescribir el Capítulo 3.

Las partes marcadas con **[verificar en MATLAB]** dependen del funcionamiento interno de una
función de toolbox que no se pudo ejecutar al redactar esto.

---

## 0. Notación y parámetros

| Símbolo | Significado | Valor |
|---|---|---|
| $N \times N$ | tamaño de imagen | $1024 \times 1024$ px |
| $L$ | lado físico del barrido | $60\ \mu\text{m}$ |
| $\Delta$ | resolución espacial $L/N$ | $58.59\ \text{nm/px}$ |
| $(i, j)$ | fila $i$ (eje $y$, hacia abajo), columna $j$ (eje $x$) | — |
| $s$ | sensibilidad de la binarización adaptativa | $0.55$ |
| $n_L,\ n_R$ | ventana local / regional | $21$ px / $51$ px |
| $K$ | número de umbrales de Otsu multinivel | $6$ (→ 7 clases) |
| $A_{\min}$ | área mínima por componente conexa | $50$ px |
| $c_{fb}$ | cobertura mínima antes del respaldo | $0.15$ |
| $r$ | radio del cierre morfológico | $3$ px ($\approx 176$ nm) |
| $k_{spur}$ | iteraciones de poda del esqueleto | $5$ |
| $w$ | ventana RLOESS | $50$ filas |
| $\alpha$ | umbral de longitud para CNTA | $2000$ nm |
| $\sigma_d,\ \sigma_i$ | escalas del tensor de estructura | $2$ px / $8$ px |

Estadísticos robustos usados a lo largo del pipeline, para un conjunto de valores $\{x\}$:

$$
\mathrm{med}(x) = \text{mediana}, \qquad
\mathrm{MAD}(x) = \mathrm{med}\big(|x - \mathrm{med}(x)|\big), \qquad
P_q(x) = \text{percentil } q.
$$

Conectividad: todas las componentes conexas se definen con vecindad de 8.

---

## 1. Adquisición

Cada archivo `.ibw` contiene varios canales del barrido KPFM. Se usan:

- **Canal eléctrico** $E_{raw}$ (canal 5): amplitud del segundo armónico, $\propto \partial C/\partial z$, en metros calibrados por el sistema.
- **Canal topográfico** $T_{raw}$ (canal 1): altura de la superficie.

Ambos se rotan 90° (`rot90`) para orientar la dirección rápida de barrido en horizontal,
de modo que **cada fila $i$ corresponde a una línea de barrido**. Si los tamaños difieren,
$E_{raw}$ se reinterpola al tamaño de $T_{raw}$.

El nombre del archivo `[V][f]-[n].ibw` codifica la fabricación:

| Código | Voltaje | Código | Frecuencia |
|---|---|---|---|
| 0 | 5 V | a | 10 Hz |
| 1 | 10 V | b | 1 kHz |
| 2 | 15 V | c | 100 kHz |

Con la imagen $n \in \{1,\dots,9\}$: réplica $= \lceil n/3 \rceil$, posición $= ((n-1) \bmod 3) + 1$.

---

## 2. Corrección de crosstalk topográfico

### 2.1 Normalización robusta
Ambos canales se llevan a una escala adimensional comparable:

$$
\tilde E = \frac{E_{raw} - \mathrm{med}(E_{raw})}{\mathrm{MAD}(E_{raw})},
\qquad
\tilde T = \frac{T_{raw} - \mathrm{med}(T_{raw})}{\mathrm{MAD}(T_{raw})}.
$$

Se usan la mediana y la MAD en lugar de media y desviación estándar porque no se ven
afectadas por los valores extremos (rayones, saltos de la punta) presentes en los datos.

### 2.2 Modelo de regresión
Las derivadas direccionales de la topografía se calculan con diferencias centrales
(diferencias de un lado en los bordes):

$$
\frac{\partial \tilde T}{\partial x}(i,j) \approx \frac{\tilde T(i,j+1) - \tilde T(i,j-1)}{2},
\qquad
\frac{\partial \tilde T}{\partial y}(i,j) \approx \frac{\tilde T(i+1,j) - \tilde T(i-1,j)}{2}.
$$

Se plantea un único modelo lineal **para toda la imagen**:

$$
\tilde E(i,j) = \beta_0 + \beta_1 \tilde T(i,j) + \beta_2 \frac{\partial \tilde T}{\partial x}(i,j) + \beta_3 \frac{\partial \tilde T}{\partial y}(i,j) + \varepsilon(i,j).
$$

Apilando los $N^2$ píxeles como filas, $\mathbf{e} = \mathrm{vec}(\tilde E) \in \mathbb{R}^{N^2}$ y

$$
\mathbf{X} = \Big[\ \mathrm{vec}(\tilde T)\ \ \ \mathrm{vec}(\partial_x \tilde T)\ \ \ \mathrm{vec}(\partial_y \tilde T)\ \ \ \mathbf{1}\ \Big] \in \mathbb{R}^{N^2 \times 4},
$$

los coeficientes se obtienen por mínimos cuadrados ordinarios:

$$
\hat{\boldsymbol\beta} = \arg\min_{\boldsymbol\beta} \|\mathbf{e} - \mathbf{X}\boldsymbol\beta\|_2^2 = (\mathbf{X}^\top \mathbf{X})^{-1}\mathbf{X}^\top \mathbf{e}.
$$

(En MATLAB `X \ e`, resuelto por factorización QR.)

### 2.3 Sustracción
La componente explicada por la topografía, $\hat E_T = \mathbf{X}\hat{\boldsymbol\beta}$, se resta **píxel a píxel**:

$$
E_{corr}(i,j) = \tilde E(i,j) - \hat E_T(i,j).
$$

Lo que se resta es un mapa completo, distinto en cada píxel, no una constante global ni por fila.

### 2.4 Propiedades
Por construcción de mínimos cuadrados, el residuo es ortogonal a cada columna de $\mathbf{X}$:

$$
\mathbf{X}^\top \mathrm{vec}(E_{corr}) = \mathbf{0}.
$$

Como $\mathbf{X}$ incluye la columna de unos, $E_{corr}$ tiene media cero y **covarianza (y correlación de Pearson) exactamente nula** con $\tilde T$, $\partial_x \tilde T$ y $\partial_y \tilde T$. Por eso la correlación eléctrico–topográfica posterior a la corrección es $\approx 10^{-16}$, es decir, cero numérico. Para mostrar el efecto de la corrección conviene reportar:

- la correlación **antes** de la corrección, $|r(\tilde E, \tilde T)|$, y
- el coeficiente de determinación $R^2 = 1 - \|E_{corr}\|^2 / \|\tilde E - \bar{\tilde E}\|^2$, que es la fracción de la variación del canal eléctrico atribuida a la topografía.

---

## 3. Filtro de ruido impulsivo (sal y pimienta selectivo)

Para una imagen $I$ y una ventana $k_1 \times k_2$:

1. **Filtro de mediana** (MATLAB `medfilt2`, relleno de ceros en el borde):

   $$
   M(i,j) = \mathrm{med}\{ I(u,v) : (u,v) \in W_{k_1 \times k_2}(i,j) \}.
   $$

2. **Residuo absoluto**: $R(i,j) = |I(i,j) - M(i,j)|$.

3. **Estimación robusta del nivel de ruido**:

   $$
   \hat\sigma = \frac{\mathrm{med}(R)}{0.6745}.
   $$

   Justificación: si el residuo de un píxel normal sigue una distribución $\mathcal N(0,\sigma^2)$, entonces $|R|$ tiene mediana $\Phi^{-1}(0.75)\,\sigma = 0.6745\,\sigma$, donde $\Phi$ es la función de distribución normal estándar. Dividir entre 0.6745 da un estimador consistente de $\sigma$. Como la mediana ignora hasta el 50 % de valores anómalos, los propios *outliers* no inflan la estimación.

4. **Reemplazo selectivo**: solo se modifican los píxeles anómalos.

   $$
   I_{out}(i,j) =
   \begin{cases}
   M(i,j), & R(i,j) > n\,\hat\sigma \\
   I(i,j), & \text{en otro caso.}
   \end{cases}
   $$

Instancias usadas:

| Instancia | Entrada | Ventana | $n$ | Objetivo |
|---|---|---|---|---|
| SyP 1 | $E_{corr}$ | $5 \times 5$ | 3 | píxeles aislados extremos |
| SyP 2 | $E_{fondo}$ | $5 \times 1$ | 2 | líneas horizontales impulsivas |
| SyP en $E_B$ | $E_{corr,B}$ | $5 \times 5$ | 3 | ídem SyP 1 en escala física |

**La ventana $5 \times 1$ es vertical: 5 filas por 1 columna.** Cada píxel se compara solo con los dos píxeles de arriba y los dos de abajo en la misma columna. Si una línea de barrido completa (o un tramo) está desplazada respecto a sus vecinas, su residuo vertical es grande y se reemplaza. Una ventana horizontal no detectaría esto, porque todos los píxeles de la línea defectuosa tendrían vecinos igual de defectuosos.

---

## 4. Corrección de fondo por fila

Se aplica a $E_1$ (salida de SyP 1) y elimina el desplazamiento de nivel de cada línea de barrido. Para cada fila $i$, con vector $I_i = E_1(i,\cdot)$:

1. **Variabilidad relativa**:

   $$
   \rho_i = \frac{\mathrm{MAD}(I_i)}{P_{95}(I_i) - P_5(I_i)}.
   $$

2. **Percentil adaptativo**:

   $$
   p_i = \min\!\big(45,\ \max(25,\ 40 - 20\,\rho_i)\big)\ \%.
   $$

3. **Nivel de fondo**: mediana de los píxeles por debajo del percentil $p_i$:

   $$
   b_i = \mathrm{med}\{ I_i(j) : I_i(j) \le P_{p_i}(I_i) \}.
   $$

4. **Sustracción**: $E_{fondo}(i,j) = I_i(j) - b_i$.

Fundamento: los CNTs aparecen como valores altos del gradiente de capacitancia. Por eso los píxeles más bajos de cada fila son mayoritariamente matriz polimérica, y su mediana estima el nivel base de esa línea. Al restarla se alinean todas las filas al mismo fondo.

**Comportamiento real del percentil.** Como $\rho_i \ge 0$, siempre se cumple $40 - 20\rho_i \le 40$: la cota superior de 45 % nunca se alcanza. Para llegar a la cota inferior de 25 % haría falta $\rho_i \ge 0.75$, lo que no ocurre en distribuciones realistas. Valores de referencia:

| Tipo de fila | $\rho$ | $p$ |
|---|---|---|
| ruido gaussiano puro | ≈ 0.21 | ≈ 36 % |
| 20 % de píxeles CNT | ≈ 0.07 | ≈ 38.5 % |
| 50 % de píxeles CNT (bimodal) | ≈ 0.40 | ≈ 32 % |
| distribución uniforme | ≈ 0.29 | ≈ 34 % |

En la práctica, el fondo se estima con el 32–39 % de píxeles más bajos de cada fila. El percentil baja cuando la fila tiene una fracción grande de CNTs (distribución bimodal), justo el caso en que un percentil alto contaminaría el fondo con CNTs.

---

## 5. Normalización a $[0,1]$

Tras SyP 2 se obtiene $E_{clean}$, que se escala de forma robusta entre sus percentiles 1 y 99:

$$
E_{seg}(i,j) = \min\!\left(1,\ \max\!\left(0,\ \frac{E_{clean}(i,j) - P_1}{P_{99} - P_1}\right)\right).
$$

El 1 % de valores extremos de cada lado se satura. Así, todas las imágenes quedan con el mismo rango dinámico y unos pocos píxeles no dominan la escala de los umbrales.

**Orden completo de la cadena de preprocesamiento:**

$$
E_{raw} \xrightarrow{\text{norm. robusta}} \tilde E \xrightarrow{\text{crosstalk}} E_{corr} \xrightarrow{\text{SyP }5\times5} E_1 \xrightarrow{\text{fondo}} E_{fondo} \xrightarrow{\text{SyP }5\times1} E_{clean} \xrightarrow{P_1\text{–}P_{99}} E_{seg}
$$

---

## 6. Binarización multiescala

### 6.1 Binarización local $M_L$ y regional $M_R$
Ambas usan umbralización adaptativa con estadístico gaussiano (`adaptthresh` + `imbinarize`). Para una ventana $n \times n$:

1. **Fondo local**: promedio de $E_{seg}$ ponderado con un núcleo gaussiano,

   $$
   \mu_G(i,j) = \sum_{(u,v)} G_{\sigma_n}(u-i,\ v-j)\, E_{seg}(u,v),
   $$

   donde la desviación $\sigma_n$ del núcleo la fija `adaptthresh` a partir del tamaño $n$ **[verificar en MATLAB con `edit adaptthresh`]**.

2. **Umbral escalado por la sensibilidad** (polaridad `bright`):

   $$
   \tau(i,j) = \min\!\big(1,\ \gamma(s)\,\mu_G(i,j)\big), \qquad \gamma(s) = 0.6 + (1 - s).
   $$

   Con $s = 0.55$: $\gamma = 1.05$ (**confirmado en MATLAB**: la prueba siguiente devuelve `0.5250`):
   ```matlab
   T = adaptthresh(0.5*ones(64),0.55,'Statistic','gaussian','ForegroundPolarity','bright');
   T(32,32)   % 0.525 confirma γ = 1.05
   ```

3. **Decisión**:

   $$
   M(i,j) = \begin{cases} 1, & E_{seg}(i,j) > \tau(i,j) \\ 0, & \text{en otro caso.} \end{cases}
   $$

   Es decir, un píxel es CNT si su intensidad supera en un 5 % la media gaussiana de su vecindad. Mayor sensibilidad $s$ significa menor $\gamma$, umbral más bajo y más píxeles clasificados como CNT.

#### Qué significa el factor $\gamma = 1.05$

**La idea.** La binarización adaptativa no compara cada píxel con un umbral fijo, sino con **su propio vecindario**. Primero calcula $\mu_G(i,j)$, el brillo "típico" alrededor del píxel. Luego exige que el píxel sea más brillante que ese valor típico multiplicado por un factor $\gamma$:

$$
E_{seg}(i,j) > \gamma\,\mu_G(i,j) \quad\Longleftrightarrow\quad \frac{E_{seg}(i,j)}{\mu_G(i,j)} > \gamma .
$$

El criterio es un **contraste relativo**: el cociente entre el píxel y su vecindario.

| $\gamma$ | Exigencia | Efecto |
|---|---|---|
| $> 1$ | el píxel debe ser **más brillante** que su vecindario | solo se marcan picos locales |
| $= 1$ | basta con superar el promedio local | aproximadamente la mitad de cada vecindario queda marcada |
| $< 1$ | basta con no ser mucho **más oscuro** que el vecindario | casi todo queda marcado, incluido el fondo |

**De dónde sale 1.05.** MATLAB no recibe $\gamma$ directamente, sino la *sensibilidad* $s \in [0,1]$, y la convierte con $\gamma(s) = 0.6 + (1 - s)$:

| $s$ | $\gamma$ | Interpretación |
|---|---|---|
| 0.0 | 1.60 | el píxel debe superar en 60 % a su vecindario |
| 0.3 | 1.30 | +30 % |
| 0.5 (valor por defecto de MATLAB) | 1.10 | +10 % |
| **0.55 (tesis)** | **1.05** | **+5 %** |
| 0.6 | 1.00 | igual al promedio |
| 0.8 | 0.80 | puede ser hasta 20 % más oscuro |
| 1.0 | 0.60 | puede ser hasta 40 % más oscuro |

Así se explica el nombre: a mayor sensibilidad, menos contraste se exige y se detectan más píxeles (incluidos CNTs profundos de bajo contraste, pero también más ruido de fondo).

**Ejemplo numérico** con $s = 0.55$, en una zona de fondo con $\mu_G = 0.20$, de modo que el umbral es $1.05 \times 0.20 = 0.21$:

| Píxel | $E_{seg}$ | ¿Supera 0.21? | Resultado |
|---|---|---|---|
| fondo polimérico | 0.19 | no | fondo ✔ |
| fondo con ruido | 0.205 | no | fondo ✔ |
| CNT profundo (contraste débil) | 0.24 | sí (+20 %) | CNT ✔ |
| CNT superficial | 0.60 | sí | CNT ✔ |

**Por qué el documento actual da otro resultado.** La tesis escribe el criterio como $E_{seg} > \mu_G(1 - \alpha_s)$. Con $\alpha_s = 0.55$ eso es $E_{seg} > 0.45\,\mu_G$, es decir $\gamma = 0.45$. En el ejemplo, el umbral sería $0.09$ y **los cuatro píxeles, incluido el fondo, saldrían como CNT**: un píxel solo sería fondo si fuera menos de la mitad de brillante que su vecindario. No es lo que hace el código.

**Evidencia en tus propios resultados.** En la validación de parámetros (Cap. 4) la cobertura pasa de 11.5 % con $s = 0.3$ a 45.2 % con $s = 0.8$:

- Con la fórmula del documento, $s = 0.3$ daría $\gamma = 0.7$: casi todo el fondo pasaría el umbral local y la cobertura no podría ser tan baja.
- Con $\gamma(s) = 0.6 + (1-s)$, $s = 0.3$ da $\gamma = 1.3$ (exigir +30 %, cobertura baja) y $s = 0.8$ da $\gamma = 0.8$ (cobertura alta). Esto coincide con lo observado.

**Consecuencias:**
- **Corrección para la tesis**: reemplazar la ecuación por $M_L(i,j) = 1$ si $E_{seg}(i,j) > \big(1.6 - s\big)\,\mu_G(i,j)$, y explicar que con $s = 0.55$ el criterio equivale a un contraste local mínimo del 5 %.
- **Limitación a mencionar**: el criterio es relativo. En zonas oscuras ($\mu_G$ pequeño), un 5 % es una diferencia absoluta mínima y el ruido la supera con facilidad. Esa es la "fragmentación granular en el fondo" que muestra $M_L$, y la razón para intersecarla con $M_G$, que usa un umbral absoluto, y con $M_R$, que usa un vecindario más amplio.
- **Confirmado**: sobre una imagen constante de valor 0.5, `adaptthresh` con $s=0.55$ devuelve un umbral de $0.525 = 1.05 \times 0.5$, lo que confirma $\gamma(s) = 0.6 + (1-s)$.

| Máscara | Ventana | Papel |
|---|---|---|
| $M_L$ | $21 \times 21$ px ($\approx 1.2\ \mu$m) | detalle fino; sigue variaciones sutiles, pero genera falsos positivos granulares en el fondo |
| $M_R$ | $51 \times 51$ px ($\approx 3\ \mu$m) | contexto regional; descarta estructuras que solo son brillantes respecto a una vecindad pequeña |

### 6.2 Binarización global $M_G$: Otsu multinivel
`multithresh` divide el histograma de $E_{seg}$ en $K+1$ clases con $K$ umbrales $t_1 < \dots < t_K$, escogidos para maximizar la varianza entre clases:

$$
\{t_k\} = \arg\max \ \sigma_B^2 = \sum_{c=0}^{K} \omega_c\,(\mu_c - \mu_{tot})^2,
$$

donde $\omega_c$ es la fracción de píxeles en la clase $c$, $\mu_c$ su intensidad media y $\mu_{tot}$ la media global. Con $K = 6$ se obtienen **7 clases**. La clase más oscura, $E_{seg} < t_1$, corresponde al fondo polimérico y se descarta:

$$
M_G(i,j) = \mathbb{1}\big[E_{seg}(i,j) \ge t_1\big].
$$

Las 6 clases restantes agrupan distintos niveles de señal de CNT (superficiales y profundos). El umbral es único para toda la imagen; se trata de un método multinivel, no multiescala. El código además elimina de $M_G$ las componentes menores a $A_{\min}$, lo que no altera el resultado final (ver 6.3).

### 6.3 Integración
Un píxel pertenece a la red solo si las tres escalas coinciden, y luego se eliminan las componentes pequeñas:

$$
M_e = \mathcal{A}_{A_{\min}}\big(M_L \wedge M_G \wedge M_R\big),
$$

donde $\mathcal{A}_{A}(M)$ elimina de $M$ toda componente conexa con menos de $A$ píxeles (`bwareaopen`).

Cada componente de la intersección está contenida en una componente de $M_G$. Por tanto, una componente pequeña de $M_G$ solo puede producir componentes pequeñas en la intersección, que $\mathcal{A}$ ya elimina; por eso el filtrado previo de $M_G$ es redundante.

### 6.4 Cobertura y respaldo
$$
c = \frac{1}{N^2} \sum_{i,j} M_e(i,j).
$$

Si $c < 0.15$, se usa solo la escala local: $M_e \leftarrow \mathcal{A}_{50}(M_L)$, con los mismos parámetros. La cobertura reportada es la de la máscara final.

---

## 7. Representaciones de trabajo

### 7.1 Máscara estricta $M_e$
La salida de la sección 6.

### 7.2 Máscara morfológica $M_{mor}$
Cierre morfológico con un disco $B_r$ de radio $r = 3$ px:

$$
M_{mor} = M_e \bullet B_r = (M_e \oplus B_r) \ominus B_r.
$$

La dilatación $\oplus$ une regiones separadas por huecos de hasta $\approx 2r$ px; la erosión $\ominus$ devuelve los bordes a su posición. El resultado rellena discontinuidades de escala $\lesssim 2r\Delta \approx 350$ nm sin engrosar las estructuras. `strel('disk',3)` aproxima el disco mediante descomposición en elementos lineales (opción por defecto).

### 7.3 Esqueleto $S$
$$
S = \mathrm{spur}^{(5)}\big(\mathrm{skel}(M_{mor})\big).
$$

`bwskel` adelgaza cada componente hasta una línea de 1 px que conserva su topología (eje medial). `bwmorph(·,'spur',5)` elimina 5 veces seguidas los píxeles extremos (píxeles con un solo vecino), lo que borra ramas espurias de hasta $\approx 5$ px. Esas ramas aparecen al esqueletizar bordes irregulares.

### 7.4 Imagen eléctrica reconstruida $E_B$
Es la señal en unidades físicas para los descriptores de intensidad y de perfil.

1. **Deshacer la normalización conservando la corrección**: como $E_{corr} = (E_{raw} - \mathrm{med})/\mathrm{MAD} - \hat E_T$, multiplicando por la MAD y sumando la mediana:

   $$
   E_{corr,B} = E_{raw} - \mathrm{MAD}(E_{raw})\,\hat E_T \quad [\text{m}].
   $$

2. **SyP $5\times5$, $n = 3$** → $E_{syp}$.

3. **Perfil vertical**: $p(i) = \mathrm{med}_j\, E_{syp}(i,j)$.

4. **Tendencia RLOESS**: $\tilde p = \mathrm{rloess}_w(p)$, con $w = 50$ filas. En cada ventana de 50 filas se ajusta una parábola por mínimos cuadrados ponderados: los pesos tricúbicos $W(d) = (1 - |d|^3)^3$ privilegian las filas cercanas al centro. Luego el ajuste se repite con pesos de robustez *bisquare* calculados de los residuos, de modo que los saltos abruptos entre filas no arrastren la tendencia.

5. **Rayas**: $\delta(i) = p(i) - \tilde p(i)$, la componente de alta frecuencia fila a fila.

6. **Sustracción por fila**:

   $$
   E_B(i,j) = E_{syp}(i,j) - \delta(i).
   $$

$E_B$ no pasa por la corrección de fondo (sección 4) ni por la normalización. Así conserva los valores absolutos del gradiente y la tendencia vertical de baja frecuencia, que la sección 4 eliminaría.

**Consecuencia:** como restar una constante a una fila desplaza su mediana en esa misma constante,

$$
\mathrm{med}_j E_B(i,j) = p(i) - \delta(i) = \tilde p(i).
$$

El perfil vertical de $E_B$ es exactamente la tendencia RLOESS (ver sección 13).

---

## 8. Descriptores de distribución espacial (sobre $M_{mor}$)

### 8.1 Muestreo con líneas de barrido
Con semilla fija (`rng(42)`), se eligen 100 filas $r_1,\dots,r_{100}$ uniformemente y con reemplazo. Son las mismas filas para todas las imágenes. En cada fila, la secuencia binaria $M_{mor}(r,\cdot)$ se descompone en tramos consecutivos de unos (CNT) y ceros (polímero). Para el tramo $m$ de CNT con inicio $a_m$ y final $e_m$:

$$
\ell_m = (e_m - a_m + 1)\,\Delta \qquad \text{(longitud de tramo CNT)},
$$

$$
d_m = (a_{m+1} - e_m - 1)\,\Delta \qquad \text{(espaciado entre tramos CNT consecutivos)}.
$$

Los huecos entre el borde de la imagen y el primer o último CNT **no** cuentan como espaciado, porque no están delimitados por dos CNTs. Los tramos CNT que tocan el borde **sí** se cuentan, aunque estén truncados. Se juntan todos los $\ell_m$ y $d_m$ de las 100 líneas.

### 8.2 Ajuste lognormal
Para una muestra $\{x_k\}_{k=1}^{n}$ (espaciados o longitudes), el ajuste de máxima verosimilitud (`fitdist`) da:

$$
\hat\mu = \frac{1}{n}\sum_k \ln x_k, \qquad \hat\sigma^2 = \frac{1}{n-1}\sum_k (\ln x_k - \hat\mu)^2,
$$

con densidad y función de distribución

$$
f(x) = \frac{1}{x\,\hat\sigma\sqrt{2\pi}} \exp\!\left(-\frac{(\ln x - \hat\mu)^2}{2\hat\sigma^2}\right),
\qquad
F(x) = \Phi\!\left(\frac{\ln x - \hat\mu}{\hat\sigma}\right).
$$

(MATLAB usa la versión insesgada $n-1$ para $\hat\sigma$.) Si hay 10 medidas o menos, el descriptor se reporta como NaN.

### 8.3 CNTD: uniformidad de espaciado
La moda de la lognormal se obtiene de $\frac{d}{dx}f(x) = 0$:

$$
\eta = e^{\hat\mu - \hat\sigma^2}.
$$

El descriptor es la probabilidad de que un espaciado caiga a ±20 % de la moda:

$$
\mathrm{CNTD} = \int_{0.8\eta}^{1.2\eta} f(s)\,ds = F(1.2\eta) - F(0.8\eta).
$$

Sustituyendo $\eta$ en $F$, con $z_c = \big(\ln(c\,\eta) - \hat\mu\big)/\hat\sigma = \ln(c)/\hat\sigma - \hat\sigma$:

$$
\mathrm{CNTD} = \Phi\!\left(\frac{\ln 1.2}{\hat\sigma} - \hat\sigma\right) - \Phi\!\left(\frac{\ln 0.8}{\hat\sigma} - \hat\sigma\right).
$$

**CNTD solo depende de $\hat\sigma$**, la dispersión logarítmica de los espaciados, y no de su escala $\hat\mu$. Una $\hat\sigma$ pequeña indica una distribución concentrada y un CNTD alto, es decir, espaciado uniforme.

### 8.4 CNTA: aglomeración
Probabilidad de que un tramo de CNT supere $\alpha = 2000$ nm:

$$
\mathrm{CNTA} = \int_{\alpha}^{\infty} g(\ell)\,d\ell = 1 - G(\alpha),
$$

donde $G$ es la función de distribución lognormal ajustada a las longitudes. El resultado se recorta a $[0,1]$.

### 8.5 CNTS
$$
\mathrm{CNTS} = \frac{\mathrm{CNTA}}{\mathrm{CNTD}} \qquad (\text{NaN si alguno es NaN o } \mathrm{CNTD} = 0).
$$

---

## 9. Descriptores de intensidad (sobre $E_B$ restringida a $M_e$)

Sea $\Omega_e = \{(i,j): M_e(i,j) = 1\}$ con $|\Omega_e| = n_e$ píxeles, y la conversión $\kappa = 10^{12}$ pm/m.

$$
\bar E = \frac{\kappa}{n_e}\sum_{\Omega_e} E_B, \qquad
s_E = \kappa\sqrt{\frac{1}{n_e - 1}\sum_{\Omega_e}\big(E_B - \bar E/\kappa\big)^2}, \qquad
E_{90} = \kappa\, P_{90}\big(E_B|_{\Omega_e}\big) \quad [\text{pm}].
$$

**Gradiente medio**: el gradiente se calcula sobre toda $E_B$ con diferencias centrales (sección 2.2), y luego se promedia sobre la red:

$$
|\nabla E_B|(i,j) = \sqrt{\left(\frac{\partial E_B}{\partial x}\right)^2 + \left(\frac{\partial E_B}{\partial y}\right)^2} \quad [\text{m/px}],
$$

$$
\overline{|\nabla E|} = \frac{\kappa}{\Delta}\cdot\frac{1}{n_e}\sum_{\Omega_e} |\nabla E_B| \quad [\text{pm/nm}].
$$

Dividir entre $\Delta$ convierte la variación por píxel en una derivada espacial física.

---

## 10. Descriptores de forma (sobre $M_{mor}$)

Sean $C_1,\dots,C_{N_c}$ las componentes conexas de $M_{mor}$.

### 10.1 Elipse equivalente
Para cada componente $C_k$, con centroide $(\bar x, \bar y)$, `regionprops` calcula los segundos momentos centrales normalizados. El término $1/12$ es el momento de un píxel unitario:

$$
u_{xx} = \frac{1}{|C_k|}\sum (x - \bar x)^2 + \tfrac{1}{12}, \quad
u_{yy} = \frac{1}{|C_k|}\sum (y - \bar y)^2 + \tfrac{1}{12}, \quad
u_{xy} = \frac{1}{|C_k|}\sum (x - \bar x)(y - \bar y).
$$

Los valores propios de la matriz $\begin{pmatrix}u_{xx} & u_{xy}\\ u_{xy} & u_{yy}\end{pmatrix}$ son

$$
\lambda_{1,2} = \frac{u_{xx} + u_{yy}}{2} \pm \frac{1}{2}\sqrt{(u_{xx} - u_{yy})^2 + 4u_{xy}^2},
$$

y los ejes de la elipse con los mismos momentos son $a_k = 4\sqrt{\lambda_1}$ (mayor) y $b_k = 4\sqrt{\lambda_2}$ (menor).

### 10.2 Elongación media
$$
\mathrm{Elong} = \frac{1}{N_c}\sum_{k=1}^{N_c} \frac{a_k}{b_k} = \frac{1}{N_c}\sum_{k} \sqrt{\frac{\lambda_{1,k}}{\lambda_{2,k}}}.
$$

Vale 1 para una componente isótropa y crece con la anisotropía. Si $b_k = 0$ (componente perfectamente lineal), el código usa $b_k = 1$.

### 10.3 Área
$$
\bar A = \frac{1}{N_c}\sum_k |C_k|\,\Delta^2 \cdot 10^{-6}, \qquad
s_A = \sqrt{\frac{1}{N_c - 1}\sum_k \big(|C_k|\Delta^2 \cdot 10^{-6} - \bar A\big)^2} \quad [\mu\text{m}^2].
$$

### 10.4 Tortuosidad media (sobre el esqueleto $S$)
Para cada componente conexa $S_j$ del esqueleto:

1. Se descarta si tiene menos de 8 px o menos de 2 extremos (por ejemplo, un lazo cerrado).
2. **Distancia geodésica** $D(p, q)$: el camino más corto dentro de $S_j$, con pasos ortogonales de peso 1 y diagonales de peso $\sqrt 2$ (`bwdistgeodesic`, `quasi-euclidean`).
3. **Diámetro por doble barrido**: desde un extremo cualquiera $e_0$ se busca el extremo más lejano $A = \arg\max_e D(e_0, e)$, y desde $A$ el más lejano $B = \arg\max_e D(A, e)$. En un árbol (esqueleto sin ciclos), $D(A,B)$ es exactamente el camino más largo entre extremos. Con ciclos es una aproximación.
4. Arco y cuerda:

   $$
   L_j^{arco} = D(A,B), \qquad L_j^{cuerda} = \|A - B\|_2.
   $$

5. Se descarta si $L_j^{arco} < 15$ px.

$$
\tau = \frac{1}{M}\sum_{j=1}^{M} \frac{L_j^{arco}}{L_j^{cuerda}} \ \ge 1,
$$

donde $M$ es el número de componentes **retenidas**. $\tau = 1$ indica estructuras rectas; valores mayores, estructuras más sinuosas. Como es un cociente, no depende de $\Delta$.

---

## 11. Descriptores de orientación (tensor de estructura sobre $M_{mor}$)

1. **Suavizado de la máscara**: $G = M_{mor} * g_{\sigma_d}$, con $\sigma_d = 2$ px. Esto convierte la máscara binaria en un campo continuo cuyo gradiente apunta perpendicular a los bordes de las estructuras.
2. **Gradiente**: $(G_x, G_y) = \nabla G$, por diferencias centrales.
3. **Tensor local** (promedio gaussiano de escala $\sigma_i = 8$ px):

   $$
   J_{xx} = g_{\sigma_i} * G_x^2, \quad J_{yy} = g_{\sigma_i} * G_y^2, \quad J_{xy} = g_{\sigma_i} * (G_x G_y).
   $$

4. **Acumulación sobre la red** $\Omega_{mor} = \{M_{mor} = 1\}$:

   $$
   \mathbf{J} = \begin{pmatrix} S_{xx} & S_{xy} \\ S_{xy} & S_{yy}\end{pmatrix}, \qquad S_{ab} = \sum_{\Omega_{mor}} J_{ab}.
   $$

5. **Valores propios**:

   $$
   \lambda_{1,2} = \frac{S_{xx} + S_{yy}}{2} \pm \frac{1}{2}\sqrt{(S_{xx} - S_{yy})^2 + 4 S_{xy}^2}.
   $$

6. **Dirección dominante del gradiente**, que es el vector propio de $\lambda_1$:

   $$
   \theta_\nabla = \tfrac{1}{2}\mathrm{atan2}\big(2S_{xy},\ S_{xx} - S_{yy}\big).
   $$

   Las estructuras son perpendiculares al gradiente, así que la **orientación dominante** es

   $$
   \theta = (\theta_\nabla + 90^\circ) \bmod 180^\circ \in [0^\circ, 180^\circ).
   $$

   Convención: $\theta$ se mide desde el eje $x$ (horizontal, dirección de barrido tras el `rot90`). Como el eje $y$ de la imagen apunta hacia abajo, los ángulos crecen en sentido horario en la imagen mostrada.

7. **Coherencia**:

   $$
   C = \frac{\lambda_1 - \lambda_2}{\lambda_1 + \lambda_2} \in [0,1].
   $$

   $C \to 1$ indica que toda la red comparte una misma dirección; $C \to 0$, que no hay dirección preferente, en cuyo caso $\theta$ no es significativo. Si $|\Omega_{mor}| \le 10$, ambos se reportan como NaN.

---

## 12. Descriptores de conectividad y topología

**Cobertura total** (sobre $M_e$):
$$
c = \frac{|\Omega_e|}{N^2}.
$$

**Índice de percolación** (sobre $M_{mor}$): fracción del material en el clúster mayor.
$$
P = \frac{\max_k |C_k|}{\sum_k |C_k|} \in (0, 1].
$$

**Número de fragmentos**: $N_c$, el número de componentes conexas de $M_{mor}$.

**Longitud de red** (sobre $S$): cada enlace entre píxeles vecinos del esqueleto suma su longitud euclidiana:

$$
n_\perp = \left|\{\text{pares de píxeles de } S \text{ adyacentes en horizontal o vertical}\}\right|,
$$

$$
n_\times = \left|\{\text{pares adyacentes en diagonal sin un camino ortogonal que los conecte}\}\right|,
$$

$$
L_{red} = \big(n_\perp + \sqrt{2}\,n_\times\big)\,\Delta \cdot 10^{-3} \quad [\mu\text{m}].
$$

Se excluyen las diagonales que ya tienen un camino ortogonal (forma de "L") para no contar dos veces el mismo tramo.

---

## 13. Descriptores de perfil de gradiente (sobre $E_B$)

Perfil vertical: $q(i) = \mathrm{med}_j E_B(i,j)$, con $i = 1,\dots,N$. Por la sección 7.4, **$q = \tilde p$, la tendencia RLOESS**. Sobre él se ajusta una recta por mínimos cuadrados:

$$
\hat q(i) = m\,i + b, \qquad
m = \frac{\sum_i (i - \bar i)(q_i - \bar q)}{\sum_i (i - \bar i)^2}, \qquad b = \bar q - m\,\bar i.
$$

| Descriptor | Fórmula | Unidad |
|---|---|---|
| Pendiente | $\kappa\, m / \Delta$ | pm/nm |
| RMS del residuo | $\kappa\sqrt{\frac{1}{N}\sum_i (q_i - \hat q_i)^2}$ | pm |
| Rango | $\kappa\,(\max_i q_i - \min_i q_i)$ | pm |

**Interpretación:** como las rayas $\delta(i)$ ya se restaron, estos descriptores caracterizan la variación vertical de **baja frecuencia** de la señal:

- la pendiente es la tendencia lineal global;
- el RMS del residuo mide cuánto se curva la tendencia RLOESS respecto a la recta (no linealidad), no el ruido entre filas;
- el rango es la excursión total de la tendencia.

---

## 14. Salida

Una fila por imagen en `descriptores.csv`, con identificación (archivo, voltaje, frecuencia, réplica, posición) y los 20 descriptores:

| Grupo | Descriptores | Representación |
|---|---|---|
| Distribución espacial | CNTD, CNTA, CNTS | $M_{mor}$ (líneas de barrido) |
| Intensidad | media, desv., P90, gradiente medio | $E_B$ en $M_e$ |
| Forma | elongación, área media, área desv., tortuosidad | $M_{mor}$, $S$ |
| Orientación | orientación dominante, coherencia | $M_{mor}$ |
| Conectividad | cobertura, percolación, longitud de red, fragmentos | $M_e$, $M_{mor}$, $S$ |
| Perfil | pendiente, RMS residuo, rango | $E_B$ |
