# Tesis

Repositorio de trabajo de la tesis: documento en LaTeX, código y datos.

## Estructura

```
documento/            Documento de la tesis (LaTeX)
├── main.tex          Archivo principal
├── capitulos/        Un .tex por capítulo (\input{capitulos/...})
├── figuras/          Figuras e imágenes del documento
└── bibliografia/     Archivos .bib
codigo/               Scripts y notebooks de análisis/experimentos
datos/
├── crudos/           Datos originales — no se modifican nunca
└── procesados/       Datos limpios generados por el código
resultados/
├── figuras/          Gráficas generadas por el código
└── tablas/           Tablas generadas por el código
notas/                Avances, reuniones con el asesor, fichas de lectura
```

## Flujo de trabajo

1. `datos/crudos` → `codigo/` → `datos/procesados` y `resultados/`.
2. El documento incluye las figuras/tablas de `resultados/` (o se copian a `documento/figuras/`).
3. Los datos crudos son de solo lectura: toda transformación queda en el código, para que los resultados sean reproducibles.

## Compilar el documento

```bash
cd documento
latexmk          # genera documento/build/main.pdf
latexmk -c       # limpia archivos auxiliares
```

Los archivos auxiliares de LaTeX y el directorio `build/` están excluidos en `.gitignore`.
