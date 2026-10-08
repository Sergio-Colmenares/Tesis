function R = rutas_tesis()
% RUTAS_TESIS  Rutas del repositorio, calculadas desde la ubicación de este
% archivo (codigo/utils/). Así los scripts funcionan en cualquier computador
% sin editar rutas absolutas.
%
%   R.raiz        raíz del repositorio
%   R.crudos      datos/crudos      (archivos .ibw)
%   R.procesados  datos/procesados
%   R.resultados  resultados        (CSV)
%   R.figuras     resultados/figuras
%   R.colormap    codigo/utils/python_colormaps.mat

    utils   = fileparts(mfilename('fullpath'));
    R.raiz  = fileparts(fileparts(utils));
    R.crudos     = fullfile(R.raiz, 'datos', 'crudos');
    R.procesados = fullfile(R.raiz, 'datos', 'procesados');
    R.resultados = fullfile(R.raiz, 'resultados');
    R.figuras    = fullfile(R.raiz, 'resultados', 'figuras');
    R.colormap   = fullfile(utils, 'python_colormaps.mat');
end
