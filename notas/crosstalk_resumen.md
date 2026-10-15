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

## Pendiente de decidir
- Si se quita la curvatura de la topografía antes del ajuste (polinomio de 2.º orden por línea o perfil común) y, por tanto, se recalcula todo el pipeline.
- Cómo reformular las secciones 3.1.1 y 4.1.1 con esta evidencia.
