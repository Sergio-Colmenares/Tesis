function P = parametros_pipeline()
% PARAMETROS_PIPELINE  Parámetros del pipeline, idénticos a los de
% pipeline/Descriptores_Final.m. Los usan visor_etapas, visor_descriptores,
% pipeline_etapas y calcular_descriptores.
    P.sens = 0.55;   % sensibilidad de adaptthresh
    P.pmin = 50;     % área mínima por componente [px]
    P.otsu = 6;      % número de umbrales de multithresh
    P.vL   = 21;     % NeighborhoodSize local (actúa como sigma)
    P.vR   = 51;     % NeighborhoodSize regional (actúa como sigma)
    P.ufb  = 0.15;   % cobertura mínima antes del respaldo
    P.r    = 3;      % radio del cierre morfológico [px]
    P.spur = 5;      % iteraciones de poda del esqueleto
    P.w    = 50;     % ventana RLOESS [filas]
    P.nm_px = 60000 / 1024;  % resolución [nm/px]
    P.alpha = 2000;          % umbral de longitud para CNTA [nm]
end
