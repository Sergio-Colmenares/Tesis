function configurar()
% CONFIGURAR  Prepara una sesión nueva de MATLAB para el repositorio de la tesis.
%
%   Desde la carpeta raíz del repositorio (o desde codigo/):
%       >> run('codigo/configurar.m')      o      >> configurar
%
%   1. Agrega codigo/ y sus subcarpetas al path.
%   2. Crea resultados/ si no existe.
%   3. Revisa que estén los .ibw en datos/crudos/ y los toolboxes necesarios.

    codigo = fileparts(mfilename('fullpath'));
    addpath(genpath(codigo));
    rutas = rutas_tesis();

    if ~exist(rutas.resultados, 'dir'), mkdir(rutas.resultados); end
    if ~exist(rutas.crudos, 'dir'),     mkdir(rutas.crudos);     end

    fprintf('\nRepositorio : %s\n', rutas.raiz);
    n_ibw = numel(dir(fullfile(rutas.crudos, '*.ibw')));
    if n_ibw == 0
        fprintf(2, 'Datos crudos: NINGÚN .ibw en %s\n', rutas.crudos);
        fprintf(2, '              Copia ahí los 81 archivos (0a-1.ibw ... 2c-9.ibw).\n');
    else
        fprintf('Datos crudos: %d archivos .ibw en %s\n', n_ibw, rutas.crudos);
        if n_ibw ~= 81
            fprintf(2, '              (se esperaban 81)\n');
        end
    end

    % Toolboxes: nombre de licencia, nombre visible, para qué se usa
    tb = {
        'Image_Toolbox',             'Image Processing Toolbox',               'todo el pipeline'
        'Statistics_Toolbox',        'Statistics and Machine Learning Toolbox', 'mad, prctile, fitdist'
        'Distrib_Computing_Toolbox', 'Parallel Computing Toolbox',             'solo los barridos con parfor (opcional)'
        };
    fprintf('\nToolboxes:\n');
    for i = 1:size(tb, 1)
        ok = license('test', tb{i, 1});
        if ok, estado = 'OK      '; else, estado = 'FALTA   '; end
        fprintf('  %s %s  (%s)\n', estado, tb{i, 2}, tb{i, 3});
    end

    fprintf(['\nListo. Para empezar:\n' ...
             '  visor_etapas            %% ver el pipeline etapa por etapa\n' ...
             '  Descriptores_Final      %% generar resultados/descriptores.csv\n\n']);
end
