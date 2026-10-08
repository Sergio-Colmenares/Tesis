# Código (MATLAB)

```
codigo/
├── main_pipeline.m        Script principal: corre todo de datos/crudos a resultados/
├── config.m               Parámetros del pipeline en un solo lugar
├── preprocesamiento/      Crosstalk, filtro SyP, fondo, filtro 5x1, normalización
├── binarizacion/          Local, global (Otsu multiclase), regional, integración
├── descriptores/          Una función por grupo de descriptores
├── analisis/              Correlación, PCA, modelos de ML
├── figuras/               Scripts que generan las figuras de la tesis
└── utils/                 Funciones auxiliares (lectura de .ibw, etc.)
```

## Reglas

- **Rutas relativas**: el código lee de `../datos/crudos/` y escribe en
  `../datos/procesados/` y `../resultados/`. Nada de `C:\Users\...`.
- **Parámetros en `config.m`**: sensibilidad, ventanas, clases de Otsu,
  radio de cierre, etc. Si cambias un valor, cambia ahí y se refleja en todo.
- **Las figuras de la tesis las genera el código** (`figuras/`), y se guardan
  en `../resultados/figuras/` como PDF. Así, si corriges algo, se regeneran
  todas igual.
- **Semillas fijas** (`rng(42)`) donde haya aleatoriedad (líneas de barrido,
  Random Forest), para que los resultados sean reproducibles.
- Al empezar una sesión de MATLAB, ejecutar `addpath(genpath('codigo'))`
  desde la raíz del repositorio (o abrir el proyecto).
