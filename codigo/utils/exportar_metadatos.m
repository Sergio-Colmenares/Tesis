function T = exportar_metadatos(archivo)
% EXPORTAR_METADATOS  Extrae los parámetros de adquisición guardados por el
% software del microscopio (Asylum Research) en la nota de cada archivo .ibw.
%
%   exportar_metadatos            revisa los 81 archivos de datos/crudos y
%                                 escribe resultados/metadatos_mediciones.csv
%                                 (una fila por medición, una columna por
%                                 parámetro) para comprobar que todas se
%                                 adquirieron con la misma configuración.
%   exportar_metadatos('2b-1')    además escribe la nota COMPLETA de esa
%                                 medición en resultados/nota_2b-1.txt
%
% La nota del .ibw es un texto con líneas "Clave: Valor" separadas por
% retornos de carro. Los nombres exactos de las claves dependen de la versión
% del software; si alguna columna sale vacía, buscarla en el .txt completo.

    rutas = rutas_tesis();
    if ~exist(rutas.resultados, 'dir'), mkdir(rutas.resultados); end

    % Parámetros de interés para describir la adquisición en la tesis
    claves = {'MicroscopeModel', 'MicroscopeID', 'Version', 'Date', 'Time', ...
              'ImagingMode', 'ScanSize', 'FastScanSize', 'SlowScanSize', ...
              'ScanPoints', 'ScanLines', 'ScanRate', 'ScanAngle', ...
              'DriveFrequency', 'DriveAmplitude', 'SetPoint', ...
              'SpringConstant', 'InvOLS', 'Amp2InvOLS', 'TipVoltage', ...
              'SurfaceVoltage', 'NapMode', 'NapHeight', 'DeltaHeight', ...
              'NapDriveFrequency', 'NapDriveAmplitude', 'NapTipVoltage', ...
              'Lockin1Frequency', 'Lockin1Harmonic', 'TipSerialNumber'};

    archivos = dir(fullfile(rutas.crudos, '*.ibw'));
    if isempty(archivos)
        error('No hay archivos .ibw en %s', rutas.crudos);
    end

    filas = cell(numel(archivos), numel(claves) + 1);
    for k = 1:numel(archivos)
        D = IBWread(fullfile(rutas.crudos, archivos(k).name));
        nota = D.WaveNotes;
        filas{k, 1} = archivos(k).name;
        mapa = leer_nota(nota);
        for j = 1:numel(claves)
            if isKey(mapa, claves{j})
                filas{k, j + 1} = mapa(claves{j});
            else
                filas{k, j + 1} = '';
            end
        end
        if nargin >= 1 && startsWith(archivos(k).name, char(archivo))
            txt = fullfile(rutas.resultados, ['nota_' erase(archivos(k).name, '.ibw') '.txt']);
            fid = fopen(txt, 'w');
            fprintf(fid, '%s', strrep(nota, char(13), newline));
            fclose(fid);
            fprintf('Nota completa -> %s\n', txt);
        end
    end

    T = cell2table(filas, 'VariableNames', [{'archivo'}, claves]);
    salida = fullfile(rutas.resultados, 'metadatos_mediciones.csv');
    writetable(T, salida);
    fprintf('Metadatos de %d mediciones -> %s\n\n', numel(archivos), salida);

    % Resumen: parámetros que NO son iguales en todas las mediciones
    fprintf('Parámetros con valores distintos entre mediciones:\n');
    hay = false;
    for j = 1:numel(claves)
        v = unique(T.(claves{j}));
        if numel(v) > 1 && ~ismember(claves{j}, {'Date', 'Time'})
            fprintf('  %-18s %d valores distintos\n', claves{j}, numel(v));
            hay = true;
        end
    end
    if ~hay, fprintf('  ninguno (sin contar fecha y hora)\n'); end
end

function mapa = leer_nota(nota)
    mapa = containers.Map('KeyType', 'char', 'ValueType', 'char');
    lineas = regexp(nota, '[\r\n]+', 'split');
    for i = 1:numel(lineas)
        p = strfind(lineas{i}, ':');
        if isempty(p), continue; end
        clave = strtrim(lineas{i}(1:p(1) - 1));
        valor = strtrim(lineas{i}(p(1) + 1:end));
        if ~isempty(clave) && ~isKey(mapa, clave)
            mapa(clave) = valor;
        end
    end
end
