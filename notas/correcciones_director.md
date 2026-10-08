# Correcciones del director — Trabajo_de_Grado_SC_1_Comments2.pdf

Comentarios extraídos del PDF, en orden de aparición. «Pág.» = página del PDF (entre paréntesis, número impreso). Las citas en cursiva son el texto resaltado; «Sugiere escribir» corresponde a cuadros de texto añadidos sobre la página.


## 3.1.1 Corrección de Crosstalk Topográfico

- Pág. 27 (22) — resaltado: *«variaciones direccionales de la topografía. Los coeficientesεise calculan por mínimos cuadrados. Laaproximación obtenida en (3.1) se resta a la señal eléctrica normalizada, eliminando las variacionessuaves originadas en la topografía.»*
- [ ] **Pág. 27 (22) · Comentario:**
  > El valor obtenido de la ecuación 3.1 se hace por fila (línea) de la matriz que conforma una imágen? o se hace globalmente sobre la matriz completa?
  > Que es lo que se resta? un valor constante a todos los puntos de la matriz?
  > O se resta un valor constante (diferente) para cada línea de  la matriz?

## 3.1.2 Filtrado de Ruido Impulsivo

- [ ] **Pág. 27 (22) · Comentario:**
  > Cual es el kernel
- Pág. 27 (22) — resaltado: *«íxel a partir de un kernel definido. La mediana es insensible a los propios outliers,»*
- [ ] **Pág. 27 (22) · Comentario:**
  > que represetna el valor 0,6745 y de donde surge?
- [ ] **Pág. 27 (22) · Comentario:**
  > No me queda claro en donde se usa cada instancia del filtro.
  > Se usan ambas instancias despues de la correción de crosstalk, cierto?

## 3.1.3 Corrección de Fondo y Artefactos de Barrido

- [ ] **Pág. 27 (22) · Comentario:**
  > Me parece confuso el título. 
  > Acaá solamente estas haciendo una correción del Fondo, no veo como es la correción de artefactos de barrido.
  > Me parece que la correción de artefactos de barrido se hacen con el kernel [5x1] que se usa para la remoción de lineas horizontales.
  > En ese sentido, me parece mejor que coloques primero esta sección de correción de fondo y después la sección de ruido impulsivo.
- Pág. 27 (22) — resaltado: *«Corrección de Fondo y Artefactos de BarridoTras la corrección lineal de crosstalk y la limpieza de outliers, se ajustan las filas para»*

## Capítulo 4 — Resultados (introducción)

- [ ] **Pág. 41 (36) · Sugiere escribir:**
  > Por otro lado,
- [ ] **Pág. 41 (36) · Sugiere escribir:**
  > Matrices

## 4.1.1 Corrección de Crosstalk Topográfico

- [ ] **Pág. 41 (36) · Comentario:**
  > Yo llamaría a esta primera ssubsección 4.1.1 Filtros y los organizaría de esta manera:
  > 1) Filtro crosstalk
  > 2) Filtro impulsivo (solo el SyP)
  > 3) Filtro de fondo (sin mencionar artefactos)
  > 4) Filtro de artefactos horizontales (el del kernel [5x1])
  > De esta forma coincide el orden de aparición con el orden en el que se usan en el proceso.
- [ ] **Pág. 41 (36) · Comentario:**
  > No uses el termino señal para referiste a las imágenes de la técnica de AFM.
  > Se pueden usar los siguintes términos:
  > 1) Canal eléctrico y canal topográfico
  > 2) Gradiente de capacitancia para el canal eléctrico específico del que provienen las imágenes que estas usando.
  > 3) Imágenes de EFM-2w para referirse al canal eléctrico
  > 4) Imágenes de topografía.
  > Mi recomendación es usar 1) o 2) son las mas claras y usadas en la literatura.
- [ ] **Pág. 41 (36) · Comentario:**
  > reporta le coeficiente de correlación
- Pág. 41 (36) — resaltado: *«reporta la correlación de Pearson entre la se»*
- Pág. 41 (36) — resaltado: *«ñal eléctrica y la topográfica antes»*
- [ ] **Pág. 41 (36) · Comentario:**
  > Usando la ecuación 3.1
- Pág. 41 (36) — resaltado: *«ón, para las 9 im»*
- [ ] **Pág. 42 (37) · Sugiere escribir:**
  > Tabla
- Pág. 42 (37) — resaltado: *«Cuadro 4.1: Correlaci»*
- Pág. 42 (37) — resaltado: *«ñal eléctrica»*
- [ ] **Pág. 42 (37) · Comentario:**
  > Espero que selecciones un set de datos en donde los coeficientes de correlación sean los mas altos para poner la tbla ejemplo.
- [ ] **Pág. 42 (37) · Comentario:**
  > Dado que la correción de crosstalk es muy suave o sutíl. Esta figura no ayuda a evidenciar su importancia.
  > Mi sugerencia es usar una sola imagen de un set en donde la correción de crosstalk sea significativa (que se alcance a notar aunque sea un poco).
  > Con esa imagen seleccionada colocar el canal topográfico (en gris) el canal eléctrico sin correccion (tal como lo tienes) y luego el canal electrico después de la corrección. Con solo una imagén de cada cosa tenemos. No uses el set completo.
- [ ] **Pág. 42 (37) · Comentario:**
  > Reporta el valor absoluto del coeficiente.
  > En la tabla coloca coeficiente de correlación en lugar de: Corr. pre-filtro.
  > coloca la columna de la correlación post filtro. Si las unidades son muy pequeñas usa notación científica o prefijos de ingeniería.
- [ ] **Pág. 42 (37) · Comentario:**
  > Debes mencionar esta figura en el texto del documento.
  > La figura 4.1 muestra el antes (a) y el despues (b) de aplicar el método de corrección de crosstalking topográfico. En general se observa una reducción de ….. como por ejmplo para la imagen R1-P2.
- [ ] **Pág. 42 (37) · Comentario:**
  > Reporta el valor abosulto del coeficiente de correlación. No nos interesa si es positiva o negativa.
- Pág. 42 (37) — resaltado: *«Figura 4.1: Mosaicos»*
- [ ] **Pág. 42 (37) · Comentario:**
  > Unifica la terminología. 
  > Es modelo, prefiltro, método de correción, …
- [ ] **Pág. 42 (37) · Comentario:**
  > USa la misma terminología para no confundir al lector.
  > Es modelo o es correción?
  > o es modelo de correción de crosstalking topográfico?
  > Importante puedes poner entre parentesis una referencia a la seccion en el documento donde describes el proceso de correción. Por ejemplo: (ver sección 3.1.1 con los detalles del…)
  > Tambien se puede hacer referencia a la ecuación 13 (la que se usa)

## 4.1.2 Filtrado de Ruido Impulsivo

- [ ] **Pág. 42 (37) · Comentario:**
  > Nuevamente y como estrategia general es. muy importante que referencies ya sea el numero de la sección donde se describe el proceso del método o la ecuación que usas.
  > Ejemplo (ver sección 3.2)
  > De esta manera el lector puede ir rápidamente a la sección si tiene dudas de como funciona el método.
- [ ] **Pág. 42 (37) · Comentario:**
  > Muy importante, en esta sección hay una especie de combunacion entre filtrado de ruido y filtrado de fondo.
  > SI vamos a la sección de métodos se encuentra primero el filtrado impulsivo y luego el filtrado de fondo, pero entiendo que en la segunda instancia es necesario hacer primero el filtrado de fondo y luego el filtrado impulsivo de líneas horizontales.
  > Mi sugerencia es que los coloques en el orden en el que se usan.
- Pág. 42 (37) — resaltado: *«Filtrado de Ruido Impulsivo»*
- [ ] **Pág. 42 (37) · Comentario:**
  > Aquí mencionas tabla, pero abajo aparece: cuadro y figura. Me pregunto a que te estas refiriendo?
  > Podrías llamar a todo lo que se presenta abajo comom figura 4.2.
  > La figura 4.2 tendria a la derecha las imágenes de los canales eléctricos y a la derecha las tablas con los valores cuantitativos.
- [ ] **Pág. 43 (38) · Comentario:**
  > No pongas esta descripción tan compacta. mejor usa un enter y que se lea completo: Filtro Sal y Pimienta [5x5]
  > Filtro Fondo [5x1]
- [ ] **Pág. 43 (38) · Comentario:**
  > No creo que sea necesario colocar una tabla con el set completo.
  > LA global dejarla para explicar globalmente como cambia el set de datos.
  > Mejor genera las tablas de cada set y colcarlas en los anexos.
  > Mencionar que las tablas se encuentan en los anexos.
- [ ] **Pág. 43 (38) · Comentario:**
  > Las imágenes se ven muy bien, pero de nuevo creo que es mejor colocar solamente una en lugar del set completo. 
  > La idea es que se vea muy bien el efecto. De este set yo elegiría la primera o la segunda. El cambio me parece fantástico.
- [ ] **Pág. 43 (38) · Comentario:**
  > Esta descripción estadística aunque interesante se enecuentra por ahora desconectada del propósito de la sección. 
  > La idea es demostrar que los filtros funcionan en relación a que mejoran la calidad de la imágen. 
  > En mi opinión debes reslatar (escrito en ele texto) en primer lugar la remoción de líneas horizontales y la eliminación de esas regiones de fondo con mayor intensidad. Por un lado la remoción de líneas horizontales tiene como impacto positivo que los nanotubos de carbono no se van a cortar o dividir. En otras palabras las regiones de CNTs se van a ver mejoradas morfologicamente. Por otro lado remover los fondos de mayor intensidad permite resaltar el contraste entre regiones con CNTS y el polimero En otras palabras s efortalece morfologicamente el fondo.
- Pág. 43 (38) — resaltado: *«La primera instancia reemplaza en promedio el 3.73 % de los píxeles a nivel global, conun máximo individual del 47.32 % sobre el conjunto completo. La segunda instancia reemplaza enpromedio el 23.18 % global, con un mínimo del 14.26 % y un máximo del 46.44 %.»*
- [ ] **Pág. 43 (38) · Comentario:**
  > Los valores estadisticos que reportas, especialmente los globales son dificiles de interpretar. Por ejemplo que le maximo sea 47.32% puede ser por la presencia de unas pocas imágenes con presencia de gran cantidad de artefactos.
  > La clave aca e spoder asociar estos datos estadisticos globales con una descripcion de la situacion o calidad de las imagenes originales. Poder decir que en su mayoria adolecian de artefactos horizontales o de fondos con reslatos muy bruscos.

## 4.1.3 Corrección de Artefactos de Barrido

- [ ] **Pág. 44 (39) · Comentario:**
  > Fijate enlas sugerencias de las secciones pasadas:
  > 1) nombre de la figura
  > 2) referencia a la seccion de metodos o la ecuacion usada
  > 3) una imagen ejemplo (selecciona una en la que se note el cambio) en lugar del set completo
  > 4) datos globales pero no la tabla del set completo
  > 5) Tablas de set en los anexos y mencionar que van en los anexos.
  > 6) Conectar la informacion global con la fomra en que cambia el set de datos
  > 7) Explicar como se ve la mejora al hacer este proceso. En que se afecta la calidad de la imagen al hacer este proceso.
- Pág. 44 (39) — resaltado: *«Corrección de Artefactos de Barrido»*
- [ ] **Pág. 45 (40) · Sugiere escribir:**
  > 4.1.4 Pipeline de binarización de imágenes

## 4.1.4 Segmentación Multiescala y Binarización

- [ ] **Pág. 45 (40) · Comentario:**
  > Mencionales explicitamente (regional, global, local) y refrencia la sección de métodos en donde se explican.
- [ ] **Pág. 45 (40) · Comentario:**
  > Explica unpoco mejor esta parte.
- Pág. 45 (40) — resaltado: *«integración de tres binarizaciones complementarias. La configuración del pipeline (sensibilidad0,55,ventana local21px, ventana regional51px,6clases en Otsu,50píxeles mínimos por componente)»*
- [ ] **Pág. 45 (40) · Comentario:**
  > Nuevamente, sele ciona solament una imágen y muestra las 3 binarizaciones.
  > Coloca el título de cada binarización encima de la figura para distinguir rápidamente entre local, global y regional
- [ ] **Pág. 46 (41) · Comentario:**
  > Esto, está bien pero debes expandir con mas detlle la idea y referencia la figura, ejemplo: (ver figura 4.4b).
  > Lo mismo para la global y regional.
- Pág. 46 (41) — resaltado: *«La binarización local recupera estructuras de alta definición pero introduce fragmentacióngranular en regiones de fondo. La binarización global produce regiones de mayor extensión espacial»*
- [ ] **Pág. 46 (41) · Sugiere escribir:**
  > para la posterior etapa de extracción de descriptores
- [ ] **Pág. 46 (41) · Comentario:**
  > Nueavmente, usa una imágen representativa.
  > No creo necesaria la tabla del set completo, pero si los datos estadísitcos globales.
  > Luego hacer un análisis de como queda estadísticamente el cambio en el nuevo data set binarizado.
- [ ] **Pág. 47 (42) · Sugiere escribir:**
  > 4.4.5 Validación de los parámetros del pipeline de binarización de imágenes
- [ ] **Pág. 47 (42) · Comentario:**
  > sin paréntisis, en lugar usar :
  > y colocar entre paréntisis el valor elegido de cada parámetro.
- [ ] **Pág. 47 (42) · Sugiere escribir:**
  > parámetros: sensibilidad (0.5), píxeles (50),  …
- [ ] **Pág. 47 (42) · Comentario:**
  > Vale la pena un párrafo que explique cada componente. Esto para no tener que regresar a la sección de métodos.
  > De hecho, estos términos no están explicitamente definidos en la sección de métodos. Ejemplo:
  > Ventana local: Región de nxn pixeles alrededor de cada pixel central de la imágen original filtrada, utilizadapara estimar intensidad media del fondo y generar la mascara local ML descrita en la sección 3.1.4.
- [ ] **Pág. 47 (42) · Comentario:**
  > Alguna razón por la cual no se eligieron la misma cantidad de puntos para todos los parámetros?
- [ ] **Pág. 47 (42) · Comentario:**
  > Cobertura media de qué?
  > Coberura de CNTs con respecto a toda la imágen?
  > Por favor acá colocar una definicón formal de:
  > Número promedio de componentes conexas.
- [ ] **Pág. 47 (42) · Comentario:**
  > Componenres conexas?
  > Es decir regiones de CNTs?
  > Por favor acá colocar una definicón formal de:
  > Número promedio de componentes conexas.
- Pág. 47 (42) — resaltado: *«número medio de componentes conexasNc»*
- Pág. 47 (42) — resaltado: *«áscara estrictaMe(sin»*
- Pág. 47 (42) — resaltado: *«étricas se computan sobre la m»*
- [ ] **Pág. 47 (42) · Comentario:**
  > Estas métricas de cobertura y componentes conexos que quieren decir o que se espera?
  > Se espera maxima cobertura y maximo compoenentes conexos?
  > Las métricas se scaan sobre una sola imagen para hacer esta validación?
  > Para una misma imagén se espera que la selección de parámetros del pipeline maximice o minimice las métricas de cobertura y conexión?
- [ ] **Pág. 47 (42) · Comentario:**
  > A que se debe esta decisión?
  > No es mejor sobre Mmorf?
- [ ] **Pág. 48 (43) · Comentario:**
  > Un detalle importante para comparacion entre prámetros es tenenr los límites de los ejes iguales para todos. 
  > Por ejemplo da la sensación que para la ventana local la cobertura media aumenta rápidamente con el incremento en pixeles. Pero al ver los valores del eje y solo subió un 5% en total. Eso no es mucho.
  > Yo pondria aproximadamente: Nc de 100 a 250 y Cobertura de 15% a 35% para todas las gráficas.
- [ ] **Pág. 48 (43) · Comentario:**
  > Estas gráficas son muy importantes ya que indican como afectan los prámetros del pipeline a la gráfica.
  > Creo que especialment elo que afecta es la cantidad de espacio definido por los CNTs y que tan cercanos están.
  > Lo dificil de entender es que es lo que se busca, maximizar, minimizar o balancear? 
  > Lo que veo en las gráficas es que las métricas cambian drásticamente con modificaciones menores en los prámetros.
- [ ] **Pág. 48 (43) · Comentario:**
  > Nueva métrica.
  > Hay que definirla explícitamente.
- Pág. 48 (43) — resaltado: *«ón normalizada FN) en funci»*
- [ ] **Pág. 49 (44) · Comentario:**
  > No se como interpretar esta gráfica ya que no entiendo las métricas: Cv cobertura, Cobertura media, Nc, FN.
- [ ] **Pág. 50 (45) · Comentario:**
  > No se como interpretar esta gráfica ya que no entiendo las métricas: Cv cobertura, Cobertura media, Nc, FN.
- [ ] **Pág. 51 (46) · Comentario:**
  > No se como interpretar esta gráfica ya que no entiendo las métricas: Cv cobertura, Cobertura media, Nc, FN.
- [ ] **Pág. 51 (46) · Comentario:**
  > Razonables en que sentido?
  > Que significa que esten en esos valores específicos?
- Pág. 51 (46) — resaltado: *«mantienen razonables a la vez. Ademas, la configuraci»*
- [ ] **Pág. 51 (46) · Comentario:**
  > La comparación es muy interesante pero no me queda claro como interpretar los resultados.
  > Cómo se que un método es mejor que otro?
  > Por ejemplo, el método es mejor si la cobertura es la mayor o la menor? Es difícilestablecer que es mejor o peor en estos casos. Además, estos valores dependen de la imágen cierto? 
  > En una imágen binarizada si hay poca cobertura puede ser por: 1) hay pocos nanotubos en la imágen original, 2) el proceso de binarización fue muy estricto y entonces ignoró regiones con nanotubos. Pero entonces como saber si es un problema del proceso de binarización?
- Pág. 51 (46) — resaltado: *«Comparación con Métodos Alternativos»*
- [ ] **Pág. 52 (47) · Comentario:**
  > Por que no hay CV de la NC?
- Pág. 53 (48) — resaltado: *«evaluadas. El mecanismo de respaldo se interpreta no como una corrección de imágenes patológicas,sino como una salvaguarda metodológica para los casos en que la calidad de adquisición invalida lossupuestos sobre los que opera la conjunción de las tres escalas.»*

## 4.2 Validación de las Representaciones de Trabajo

- Pág. 53 (48) — resaltado: *«Mmor, la ventana de la corrección de rayas RLOESS empleada para construir la imagen eléctricareconstruidaEB, y el número de iteraciones de poda de pixeles aplicado al esqueleto. Esta sección»*
- [ ] **Pág. 53 (48) · Comentario:**
  > Que es esta imagen y para que se usa?

## 4.2.1 Radio del Cierre Morfológico

- [ ] **Pág. 53 (48) · Comentario:**
  > Que se espera que de este análisis? Que el radio elegído es el mejor por cuáles razones?
  > Podrías usar unas imágenes que indiquen por ejemplo tres condiciones: 1) buen cierre morfológico, 2) un cierre regular y 3) un cierre malo.
- Pág. 53 (48) — resaltado: *«10px (⇓59–586 nm en escala física). Para cada radio se midieron, sobre la máscara morfológicaresultante, la cobertura, el número de componentes, la longitud del esqueleto post-poda, elíndice depercolación, y dos métricas diferenciales respecto a la máscara estrictaMe: el material agregado(!cob) y las componentes fusionadas (!Nc).»*
- [ ] **Pág. 53 (48) · Comentario:**
  > Debes ayudarle al lector a entender este resultado. Con tal fin es encesario que expliques que significan las métricas que estas usando.

## 4.2.4 Extracción de Descriptores Morfológicos

- [ ] **Pág. 60 (55) · Comentario:**
  > Esto significa que se extrae un único valor por imágen?
  > En el caso por ejemplo de los descriptores de distribución espacial, usualmente por imagen sale una distribucion de datos, ya que cada objeto sobre la imagen aporta. En estos casos que estas usando, media, varianza, etc? Son distribuciones normales? Se ajustan a distribuciones normales?
- [ ] **Pág. 60 (55) · Comentario:**
  > Cuál es el resultado esperado de hacer este análisis a lo largo de las 81 imágenes?
  > Recuerda que las imágenes dependen de parámetros de fabricación diferentes. 
  > Entonces estas combinando los resultados de los descriptores sin importar su tipo de fabricación. Analizar resultados de esta manera es complicado.
- Pág. 60 (55) — resaltado: *«valores por descriptor a lo largo del dataset. Esta sección reporta esas distribuciones agrupadas porcategoría y describe la forma, mediana y rango de cada una. La definición operacional de cada»*
- [ ] **Pág. 60 (55) · Comentario:**
  > Especifíca la sección.
- Pág. 60 (55) — resaltado: *«ítulo de Metodología.»*
- Pág. 60 (55) — resaltado: *«CNTD presenta una distribución asimétrica con mediana 0,092 y rango entre 0,072 y 0,129.CNTA presenta asimetría hacia valores bajos, con mediana 0,231 y la mayoría de los valores entre0,218 y 0,245. CNTS es el más simétrico de los tres, con mediana 2,51, la mayoría de los valoresentre 2,26 y 2,75 y rango entre 1,36 y 3,57.»*
- [ ] **Pág. 60 (55) · Comentario:**
  > Qué aportan estos resultados a la discusión de la tésis? Que se puede concluir o discutir de estos datos?
- [ ] **Pág. 60 (55) · Comentario:**
  > No entiendo esta parte. Ahora si se va a a nalizar por tipo de voltaje aplicado durantel al fabricación?
- Pág. 60 (55) — resaltado: *«valor depende del método de binarización. Para evaluar si la dependencia de CNTS con el voltajereportada en [4] se reproduce sobre este dataset, se recalcularon los descriptores con tres binarizacio-»*
- Pág. 61 (56) — resaltado: *«El método de binarización del pipeline produce máscaras válidas en las 81 imágenes; elmétodo de [4] aplicado a la señal cruda falla en 50 de ellas (62 %), al generar máscaras demasiadoescasas para ajustar la distribución de espaciados. Los valores de CNTS difieren marcadamente entremétodos sobre las mismas imágenes. En cuanto a la dependencia con el voltaje a 10 Hz, ninguno delos tres métodos reproduce el descenso monótono2,2↘2,0↘1,7reportado en [4]: el pipelinearroja2,33↘2,65↘2,58(correlación de Spearman con el voltajeϖ=↔0,01); el método de[4], sobre las imágenes en que es evaluable,0,08↘0,54↘0,23(ϖ=↔0,13); y el umbral de [4]sobreEseg,0,96↘1,09↘1,86(ϖ=+ 0,16). [-¿DISCUSI´ON: el método de referencia tampocorecupera la tendencia, lo que descarta el pipeline como causa y remite a la diferencia de fabricacióny a la ausencia de la muestra de referencia 0 V].»*
- [ ] **Pág. 61 (56) · Comentario:**
  > Esto es interessante, pero necesito que me lo expliques.
- Pág. 61 (56) — resaltado: *«del segundo armónico, en metros calibrados por el sistema con la sensibilidad del 2.ºarmónicoAmp2InvOLS) restringida a la máscara estrictaMe. La Figura4.14muestra sus distribuciones.»*
- [ ] **Pág. 61 (56) · Comentario:**
  > No entiendo.

## 4.3.1 Estructura de Correlación y Redundancia

- Pág. 65 (60) — resaltado: *«ón de Pearson entre los 20 descriptores, ordenada»*
- [ ] **Pág. 65 (60) · Comentario:**
  > Si lo que se busca es identificar que hay redudancia en los descriptores entonces se debe hacer con el valor absoluto
- [ ] **Pág. 66 (61) · Comentario:**
  > Debe ser el valor absoluto.

## 4.3.2 Dimensionalidad Efectiva y Selección de Descriptores

- Pág. 67 (62) — resaltado: *«Se requieren ocho componentes principales para explicar el 90 % de la varianza, y ladimensionalidad efectiva estimada por elparticipation ratioes de4,9. Las tres primeras componentesconcentran el 66 % de la varianza: PC1 (39 %) está dominada por la familia de intensidad y, en sentidoopuesto, por la longitud de red y elárea media; PC2 (16 %) por los descriptores de distribuciónespacial (CNTS, CNTA, CNTD) y elíndice de percolación; y PC3 (11 %) por la coherencia, losdescriptores de perfil y la elongación. En las proyecciones sobre PC1–PC2 las imágenes de distintafrecuencia presentan una deriva parcial, mientras que las de distinto voltaje aparecen mezcladas.»*
- [ ] **Pág. 67 (62) · Comentario:**
  > Debes ampliar y mejorar la explicación.
