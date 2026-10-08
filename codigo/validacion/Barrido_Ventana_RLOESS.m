function Barrido_Ventana_RLOESS()
% =========================================================================
% Barrido_Ventana_RLOESS.m
%
% Justifica empíricamente la elección de la ventana de la corrección de
% rayas RLOESS aplicada al construir la imagen eléctrica reconstruida
% E_B. El valor del pipeline es ventana=50 filas.
%
% Idea del barrido:
%   - El M_e del pipeline no depende de la ventana RLOESS (depende solo de
%     Eseg). Por eso se calcula una sola vez por imagen.
%   - Para cada ventana en la grilla, se reconstruye E_B aplicando RLOESS
%     con ese tamaño de ventana y se computan las métricas que dependen
%     de E_B: pendiente residual del perfil, RMS del residuo, rango del
%     perfil, y los descriptores de intensidad sobre M_e (media, std, p90)
%     y el gradiente medio.
%   - El óptimo es la ventana donde:
%       * La pendiente residual es ~0 (RLOESS removió la tendencia)
%       * El rango residual del perfil es estable (no muy chico por
%         sobre-corrección ni muy grande por sub-corrección)
%       * Los descriptores de intensidad son estables (no varían mucho
%         con la ventana => elección robusta)
%
% Salida: barrido_rloess.csv -> 81 imágenes * 8 ventanas = 648 filas
% Tiempo estimado: ~8-12 min con 6 workers.
% =========================================================================

clear; clc; close all;

% -------------------------------------------------------------------------
% CONFIGURACIÓN
% -------------------------------------------------------------------------
rutas = rutas_tesis();   % rutas relativas al repositorio (codigo/utils)
inputFolder  = rutas.crudos;
outputCSV    = fullfile(rutas.resultados, 'barrido_rloess.csv');
nWorkers     = 6;

nm_por_pixel = 60000 / 1024;
m_a_pm       = 1e12;

% Grilla de ventanas (en filas). 50 es el valor del pipeline (Main.m).
v_grid = [10, 25, 50, 75, 100, 150, 200, 300];

% --- Configuración del pipeline (para construir M_e una vez por imagen) ---
pipe_sens = 0.55;
pipe_pmin = 50;
pipe_otsu = 6;
pipe_vR   = 51;
pipe_vL   = 21;
pipe_ufb  = 0.15;

% -------------------------------------------------------------------------
% LECTURA DE ARCHIVOS
% -------------------------------------------------------------------------
ibwFiles = dir(fullfile(inputFolder, '*.ibw'));
nImg     = length(ibwFiles);
if nImg == 0
    error('No se encontraron archivos .ibw en %s', inputFolder);
end
fileNames = arrayfun(@(f) f.name, ibwFiles, 'UniformOutput', false);

outDir = fileparts(outputCSV);
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('================================================================\n');
fprintf('Barrido sobre la ventana de la corrección RLOESS de E_B\n');
fprintf('================================================================\n');
fprintf('Imágenes        : %d\n', nImg);
fprintf('Ventanas        : %s\n', mat2str(v_grid));
fprintf('Pipeline (M_e)  : sens=%.2f, pmin=%d, otsu=%d, vR=%d, vL=%d, ufb=%.2f\n', ...
        pipe_sens, pipe_pmin, pipe_otsu, pipe_vR, pipe_vL, pipe_ufb);
fprintf('================================================================\n\n');

% -------------------------------------------------------------------------
% POOL PARALELO
% -------------------------------------------------------------------------
pool = gcp('nocreate');
if isempty(pool)
    pool = parpool('local', nWorkers);
end
fprintf('Workers activos: %d\n\n', pool.NumWorkers);

% -------------------------------------------------------------------------
% MONITOREO
% -------------------------------------------------------------------------
dq       = parallel.pool.DataQueue;
t_inicio = tic;
afterEach(dq, @(msg) fprintf('[%6.1f min] %s\n', toc(t_inicio)/60, msg));

% -------------------------------------------------------------------------
% PROCESAMIENTO PARALELO POR IMAGEN
% -------------------------------------------------------------------------
nV = length(v_grid);
resultados = cell(nImg, 1);

parfor k = 1:nImg
    filename = fileNames{k};
    try
        % 1. Preprocesamiento completo + reconstrucción intermedia
        [Eseg, Elec_corr_B_pre, mad_raw] = preprocesar_y_reconstruir(filename, inputFolder);

        % 2. Construcción de M_e una sola vez
        [M_e, fallback_activado] = construir_Me(Eseg, ...
            pipe_sens, pipe_pmin, pipe_otsu, pipe_vR, pipe_vL, pipe_ufb);

        cov_Me = sum(M_e(:)) / numel(M_e);
        Nc_Me  = numero_componentes(M_e);

        % 3. Barrido sobre la ventana de RLOESS
        filas = cell(nV, 1);
        for vi = 1:nV
            v_actual = v_grid(vi);
            m = evaluar_ventana(Elec_corr_B_pre, M_e, v_actual, m_a_pm, nm_por_pixel);

            filas{vi} = sprintf(['%s,'...
                '%d,'...
                '%.6f,%d,%.6e,%.4f,'...
                '%.4f,%.4f,%.4f,%.6f,'...
                '%.4f,%.4f,%.6f,'...
                '%d\n'], ...
                filename, ...
                v_actual, ...
                cov_Me, Nc_Me, ...
                m.perfil_pendiente_pm_nm, m.perfil_rms_pm, ...
                m.perfil_rango_pm, m.rango_tendencia_pm, m.rms_rayas_pm, ...
                m.intensidad_media_pm, ...
                m.intensidad_std_pm, m.intensidad_p90_pm, ...
                m.gradiente_medio_pm_nm, ...
                fallback_activado);
        end
        resultados{k} = filas;

        send(dq, sprintf('Imagen %2d/%d OK: %s', k, nImg, filename));
    catch ME
        send(dq, sprintf('ERROR imagen %d (%s): %s', k, filename, ME.message));
        resultados{k} = [];
    end
end

fprintf('\nBarrido completado en %.1f minutos.\n', toc(t_inicio)/60);

% -------------------------------------------------------------------------
% ESCRITURA DEL CSV
% -------------------------------------------------------------------------
fprintf('Escribiendo %s...\n', outputCSV);
fid = fopen(outputCSV, 'w');
fprintf(fid, ['imagen,'...
    'ventana_filas,'...
    'cov_Me,Nc_Me,perfil_pendiente_pm_nm,perfil_rms_pm,'...
    'perfil_rango_pm,rango_tendencia_pm,rms_rayas_pm,intensidad_media_pm,'...
    'intensidad_std_pm,intensidad_p90_pm,gradiente_medio_pm_nm,'...
    'fallback_activado\n']);
for k = 1:nImg
    filas = resultados{k};
    if isempty(filas), continue; end
    for vi = 1:length(filas)
        if ~isempty(filas{vi})
            fprintf(fid, '%s', filas{vi});
        end
    end
end
fclose(fid);

fprintf('\nListo. CSV en: %s\n', outputCSV);
fprintf('================================================================\n');
end


% =========================================================================
% PREPROCESAMIENTO Y RECONSTRUCCIÓN INTERMEDIA
% Devuelve:
%   Eseg            : señal normalizada para binarización (= Main.m)
%   Elec_corr_B_pre : Elec_Raw - Elec_fit*mad + median, tras SyP 5x5.
%                     Es la entrada al paso de RLOESS (sin corrección de
%                     rayas todavía). Sobre esta señal se aplicará RLOESS
%                     con cada ventana del barrido.
%   mad_raw         : MAD de Elec_Raw (necesario para deshacer escalas
%                     internamente al evaluar la ventana, no se usa
%                     explícitamente fuera porque ya está incorporado)
% =========================================================================
function [Eseg, Elec_corr_B_pre, mad_raw] = preprocesar_y_reconstruir(filename, inputFolder)
    Full     = IBWread(fullfile(inputFolder, filename));
    Elec_Raw = rot90(double(Full.y(:, :, 5)));
    Topo     = rot90(double(Full.y(:, :, 1)));
    if ~isequal(size(Elec_Raw), size(Topo))
        Elec_Raw = imresize(Elec_Raw, size(Topo));
    end

    med_raw = median(Elec_Raw(:));
    mad_raw = mad(Elec_Raw(:), 1);

    Elec_norm = (Elec_Raw - med_raw) / mad_raw;
    Topo_norm = (Topo     - median(Topo(:))) / mad(Topo(:), 1);

    [Gy, Gx] = gradient(Topo_norm);
    X        = [Topo_norm(:), Gx(:), Gy(:), ones(numel(Topo_norm), 1)];
    beta     = X \ Elec_norm(:);
    Elec_fit = reshape(X * beta, size(Elec_norm));

    % --- Eseg (pipeline de binarización) ---
    Elec_corr  = Elec_norm - Elec_fit;
    Elec_syp1  = syp_selectivo(Elec_corr, [5 5], 3);
    Elec_strip = line_strip(Elec_syp1);
    Elec_clean = syp_selectivo(Elec_strip, [5 1], 2);
    Eseg       = rescale_1_99(Elec_clean);

    % --- Elec_corr_B_pre (pipeline de E_B, antes de la RLOESS) ---
    % Misma fórmula que pipeline/Descriptores_Final.m:
    %   Elec_corr_B = Elec_Raw - Elec_fit .* mad(Elec_Raw(:),1);
    % (la versión anterior sumaba además median(Elec_Raw), lo que desplazaba
    %  E_B en una constante y alteraba los Δ% de intensidad media y P90)
    %   Elec_syp    = Etapa1_SyP_Selectivo(Elec_corr_B, [5 5], 3);
    Elec_corr_B     = Elec_Raw - Elec_fit .* mad_raw;
    Elec_corr_B_pre = syp_selectivo(Elec_corr_B, [5 5], 3);
end


% =========================================================================
% EVALUACIÓN DE UNA VENTANA RLOESS
% Aplica RLOESS con la ventana indicada para construir E_B y computa las
% métricas del perfil y los descriptores de intensidad.
% =========================================================================
function m = evaluar_ventana(Elec_corr_B_pre, M_e, v_actual, m_a_pm, nm_por_pixel)
    % 1. RLOESS sobre el perfil vertical para identificar las rayas
    perfil_V    = median(Elec_corr_B_pre, 2);
    tendencia_V = smoothdata(perfil_V, 'rloess', v_actual);
    ruido_rayas = perfil_V - tendencia_V;

    % 2. Construcción de E_B (resta de rayas a cada fila)
    [filas, cols] = size(Elec_corr_B_pre);
    Elec_B = Elec_corr_B_pre - repmat(ruido_rayas, 1, cols);

    % 3. Métricas del perfil vertical de E_B post-corrección
    perfil_B  = median(Elec_B, 2);
    x_fila    = (1:length(perfil_B))';
    p_fit     = polyfit(x_fila, perfil_B, 1);
    perfil_hat = polyval(p_fit, x_fila);
    residuos  = perfil_B - perfil_hat;

    m.perfil_pendiente_pm_nm = p_fit(1) * m_a_pm / nm_por_pixel;
    m.perfil_rms_pm          = sqrt(mean(residuos.^2)) * m_a_pm;
    m.perfil_rango_pm        = (max(perfil_B) - min(perfil_B)) * m_a_pm;

    % 4. Métricas de la tendencia capturada por RLOESS
    m.rango_tendencia_pm = (max(tendencia_V) - min(tendencia_V)) * m_a_pm;
    m.rms_rayas_pm       = sqrt(mean(ruido_rayas.^2)) * m_a_pm;

    % 5. Descriptores de intensidad sobre M_e
    vals = Elec_B(M_e);
    if isempty(vals)
        m.intensidad_media_pm = NaN;
        m.intensidad_std_pm   = NaN;
        m.intensidad_p90_pm   = NaN;
    else
        m.intensidad_media_pm = mean(vals)       * m_a_pm;
        m.intensidad_std_pm   = std(vals)        * m_a_pm;
        m.intensidad_p90_pm   = prctile(vals,90) * m_a_pm;
    end

    % 6. Gradiente medio sobre M_e
    [Gy_b, Gx_b] = gradient(Elec_B);
    mag = sqrt(Gx_b.^2 + Gy_b.^2);
    if any(M_e(:))
        m.gradiente_medio_pm_nm = mean(mag(M_e)) * m_a_pm / nm_por_pixel;
    else
        m.gradiente_medio_pm_nm = NaN;
    end
end


% =========================================================================
% CONSTRUCCIÓN DE M_e (fallback estandarizado)
% =========================================================================
function [M_e, fallback_activado] = construir_Me(Eseg, ...
    pipe_sens, pipe_pmin, pipe_otsu, pipe_vR, pipe_vL, pipe_ufb)

    thresh = multithresh(Eseg, pipe_otsu);
    BW1    = Eseg >= thresh(1);

    T_reg = adaptthresh(Eseg, pipe_sens, ...
        'NeighborhoodSize',   [pipe_vR pipe_vR], ...
        'Statistic',          'gaussian', ...
        'ForegroundPolarity', 'bright');
    BW_reg = imbinarize(Eseg, T_reg);

    T_loc = adaptthresh(Eseg, pipe_sens, ...
        'NeighborhoodSize',   [pipe_vL pipe_vL], ...
        'Statistic',          'gaussian', ...
        'ForegroundPolarity', 'bright');
    BW_loc = imbinarize(Eseg, T_loc);

    M_triple = bwareaopen(BW1 & BW_reg & BW_loc, pipe_pmin);
    cov_tri  = sum(M_triple(:)) / numel(M_triple);

    if cov_tri < pipe_ufb
        M_e = bwareaopen(BW_loc, pipe_pmin);
        fallback_activado = 1;
    else
        M_e = M_triple;
        fallback_activado = 0;
    end
end


% =========================================================================
% UTILIDADES (idénticas a los otros scripts)
% =========================================================================
function n = numero_componentes(BW)
    CC = bwconncomp(BW);
    n  = CC.NumObjects;
end

function I_out = syp_selectivo(I_in, kernel, n)
    M     = medfilt2(I_in, kernel);
    R     = abs(I_in - M);
    sigma = median(R(:)) / 0.6745;
    if sigma == 0, sigma = eps; end
    mask  = R > n * sigma;
    I_out = I_in;
    I_out(mask) = M(mask);
end

function I_out = line_strip(I_in)
    [r, ~] = size(I_in);
    I_out  = zeros(size(I_in));
    for i = 1:r
        row   = I_in(i, :);
        sigma = mad(row, 1);
        dyn   = prctile(row, 95) - prctile(row, 5);
        if dyn == 0, dyn = eps; end
        ratio  = sigma / dyn;
        p      = max(25, min(45, 40 - 20 * ratio));
        cutoff = prctile(row, p);
        bg     = row(row <= cutoff);
        if isempty(bg)
            offset = median(row);
        else
            offset = median(bg);
        end
        I_out(i, :) = row - offset;
    end
end

function I_out = rescale_1_99(D)
    lo = prctile(D(:), 1);
    hi = prctile(D(:), 99);
    if hi == lo
        I_out = zeros(size(D)); return;
    end
    I_out = max(0, min(1, (D - lo) / (hi - lo)));
end
