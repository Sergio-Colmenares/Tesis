# Código (MATLAB)

```
codigo/
├── configurar.m                   Prepara una sesión nueva de MATLAB (path, carpetas, toolboxes)
├── visor_etapas.m                 Visor interactivo: las 15 etapas del pipeline de una imagen
├── visor_descriptores.m           Visor interactivo: cómo se mide cada descriptor + tabla de los 20
├── pipeline/
│   └── Descriptores_Final.m       Pipeline completo + 20 descriptores → resultados/descriptores.csv
├── validacion/
│   ├── Barrido_Validacion.m       Barrido de parámetros de binarización (Cap. 4.1.4)
│   ├── Barrido_Radio_Cierre.m     Barrido del radio del cierre morfológico (4.2.1)
│   ├── Barrido_Ventana_RLOESS.m   Barrido de la ventana RLOESS (4.2.2)
│   ├── barrido_poda.m             Barrido de la poda del esqueleto (4.2.3)
│   ├── comparar_paper_vs_pipeline.m  CNTS con el pipeline vs. el método de [4] (4.2.4)
│   └── verificar_documento.m      Compara los números del documento con los CSV ([OK]/[FAIL])
├── figuras/
│   ├── ExportarEtapas.m           Figuras por etapa (01_raw_2b … 12_skel_2b) y stats_etapas.csv
│   └── mosaicos_2b.m              Mosaicos de descriptores del set 2b (Cap. 3.2)
├── orientacion/                   Análisis de soporte del descriptor de orientación
│   ├── diagnostico_orientacion.m  Sesgo de rejilla y formas alternativas de agregar θ
│   ├── barrido_orientacion.m      Estabilidad frente a σ_d y σ_i
│   └── estabilidad_vs_coherencia.m  Estabilidad de θ según la coherencia
└── utils/
    ├── rutas_tesis.m              Rutas del repositorio (datos/, resultados/)
    ├── parametros_pipeline.m      Parámetros del pipeline (para los visores)
    ├── pipeline_etapas.m          Pipeline de una imagen, guardando cada etapa
    ├── calcular_descriptores.m    Los 20 descriptores de una imagen (+ elementos para graficar)
    ├── parsear_fabricacion_ibw.m  Voltaje/frecuencia/réplica/posición desde el nombre
    ├── IBWread.m                  Lectura de archivos .ibw
    ├── readIBWheaders.m
    ├── readIBWbinheader.m
    └── python_colormaps.mat       Mapas de color de las figuras
```

## Cómo correrlo

1. Copiar los `.ibw` a `datos/crudos/` (no se suben al repositorio).
2. En MATLAB, desde la raíz del repositorio: `run('codigo/configurar.m')`.
3. `visor_etapas` para revisar el pipeline imagen por imagen y
   `visor_descriptores` para ver cómo se mide cada descriptor
   (flechas ←/→ para navegar, clic en un panel para verlo grande).
   Si ya existe `resultados/descriptores.csv`, `visor_descriptores` marca
   cada valor como `ok` o `DIF` frente al CSV.
4. Correr primero `Descriptores_Final` (genera `descriptores.csv`, que usan
   `barrido_poda`, `diagnostico_orientacion` y `verificar_documento`).

Todas las rutas se calculan con `rutas_tesis()`, así que no hay que editar
rutas a mano en ningún computador.

## Parámetros del pipeline

Todos los scripts usan la misma configuración: sensibilidad 0.55, Otsu con
6 umbrales, σ local 21 px, σ regional 51 px, componentes ≥ 50 px, respaldo
local si la cobertura < 15 %, cierre r = 3 px, poda 5 iteraciones y RLOESS
de 50 filas. Si se cambia alguno, hay que cambiarlo en todos.

## Reglas

- Las figuras de la tesis las genera el código y se guardan en `resultados/`.
- Semillas fijas (`rng(42)`) donde haya aleatoriedad.
- Guardar los scripts como `.m` (texto) y no como `.mlx`, para que Git
  muestre los cambios.
