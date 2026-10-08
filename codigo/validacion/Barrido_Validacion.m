function Barrido_Validacion()
% =========================================================================
% Barrido_Validacion.m  (versión final)
%
% Barrido sistemático de los parámetros del pipeline de binarización
% multiescala sobre las 81 imágenes del dataset KPFM.
%
% Cambios respecto a versiones previas:
%   - sens=0.55 se incluye explícitamente en la grilla (valor del pipeline
%     real), evitando interpolación.
%   - fallback_mode='variable': el método del fallback es el M_L del
%     Triple AND de cada configuración del barrido. Esto estandariza el
%     mecanismo de respaldo al método principal: ya no es un método aparte
%     con parámetros distintos, sino una porción del pipeline que se
%     reutiliza cuando la conjunción falla.
%
% Produce DOS CSVs:
%   preprocesamiento55.csv     -> 81 filas, métricas pre-binarización
%   barrido_binarizacion55.csv -> 81 * nConfigs filas con las métricas de
%                                  los cuatro métodos: Solo Local,
%                                  Global+Local, Triple AND, Pipeline.
%
% Grilla (7 * 4 * 2 * 4 * 3 * 4 = 2688 configuraciones):
%   sensibilidad     : {0.3, 0.4, 0.5, 0.55, 0.6, 0.7, 0.8}
%   pix_minimos      : {10, 25, 50, 100}
%   umbral_fallback  : {0.10, 0.15}
%   otsu_k           : {4, 5, 6, 8}
%   ventana_regional : {51, 101, 151}
%   ventana_local    : {9, 15, 21, 31}
% =========================================================================

clear; clc; close all;

% -------------------------------------------------------------------------
% CONFIGURACIÓN
% -------------------------------------------------------------------------
rutas = rutas_tesis();   % rutas relativas al repositorio (codigo/utils)
inputFolder    = rutas.crudos;
outputPreCSV   = fullfile(rutas.resultados, 'preprocesamiento55.csv');
outputBarCSV   = fullfile(rutas.resultados, 'barrido_binarizacion55.csv');
nWorkers       = 8;

% Modo del fallback:
%   'variable' -> reutiliza M_L del Triple AND de la configuración actual.
%                 Es la estandarización: el fallback es parte del pipeline.
%   'fixed'    -> usa parámetros fijos (fb_sens, fb_vL, fb_pmin) abajo.
fallback_mode  = 'variable';

% Parámetros del fallback fijo (solo se usan si fallback_mode='fixed')
fb_sens = 0.55;
fb_vL   = 21;
fb_pmin = 50;

% -------------------------------------------------------------------------
% GRILLA DE PARÁMETROS
% -------------------------------------------------------------------------
sens_grid = [0.3, 0.4, 0.5, 0.55, 0.6, 0.7, 0.8];
pmin_grid = [10, 25, 50, 100];
ufb_grid  = [0.10, 0.15];
otsu_grid = [4, 5, 6, 8];
vR_grid   = [51, 101, 151];
vL_grid   = [9, 15, 21, 31];

[Sg, Pg, Ug, Mg, Rg, Lg] = ndgrid(sens_grid, pmin_grid, ufb_grid, ...
                                  otsu_grid, vR_grid, vL_grid);
configs  = [Sg(:), Pg(:), Ug(:), Mg(:), Rg(:), Lg(:)];
nConfigs = size(configs, 1);

% -------------------------------------------------------------------------
% LECTURA DE ARCHIVOS
% -------------------------------------------------------------------------
ibwFiles = dir(fullfile(inputFolder, '*.ibw'));
nImg     = length(ibwFiles);
if nImg == 0
    error('No se encontraron archivos .ibw en %s', inputFolder);
end
fileNames = arrayfun(@(f) f.name, ibwFiles, 'UniformOutput', false);

outDir = fileparts(outputPreCSV);
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('================================================================\n');
fprintf('Barrido de validación del pipeline\n');
fprintf('================================================================\n');
fprintf('Imágenes        : %d\n', nImg);
fprintf('Configuraciones : %d\n', nConfigs);
fprintf('Filas barrido   : %d\n', nImg * nConfigs);
fprintf('Modo fallback   : %s\n', fallback_mode);
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
% BARRIDO PARALELO POR IMAGEN
% -------------------------------------------------------------------------
preResults = cell(nImg, 1);
barResults = cell(nImg, 1);

parfor k = 1:nImg
    filename = fileNames{k};
    try
        [Eseg, preRow] = preprocesar(filename, inputFolder);
        preResults{k}  = preRow;

        cache = precalcular_mascaras(Eseg, sens_grid, otsu_grid, ...
                                     vR_grid, vL_grid, ...
                                     fb_sens, fb_vL, fb_pmin);

        filas = cell(nConfigs, 1);
        for c = 1:nConfigs
            cfg = configs(c, :);
            filas{c} = evaluar_configuracion(cache, cfg, filename, ...
                                             sens_grid, otsu_grid, ...
                                             vR_grid, vL_grid, ...
                                             fallback_mode);
        end
        barResults{k} = filas;

        send(dq, sprintf('Imagen %2d/%d OK: %s', k, nImg, filename));
    catch ME
        send(dq, sprintf('ERROR imagen %d (%s): %s', k, filename, ME.message));
        preResults{k} = [];
        barResults{k} = [];
    end
end

fprintf('\nBarrido completado en %.1f minutos.\n\n', toc(t_inicio)/60);

% -------------------------------------------------------------------------
% ESCRITURA DE CSVs
% -------------------------------------------------------------------------
fprintf('Escribiendo %s...\n', outputPreCSV);
escribir_pre_csv(outputPreCSV, preResults);

fprintf('Escribiendo %s...\n', outputBarCSV);
escribir_bar_csv(outputBarCSV, barResults);

fprintf('\n================================================================\n');
fprintf('Listo. Total: %.1f minutos.\n', toc(t_inicio)/60);
fprintf('  -> %s\n', outputPreCSV);
fprintf('  -> %s\n', outputBarCSV);
fprintf('================================================================\n');
end


% =========================================================================
% PREPROCESAMIENTO + MÉTRICAS DE PRE-BINARIZACIÓN
% =========================================================================
function [Eseg, preRow] = preprocesar(filename, inputFolder)
    Full     = IBWread(fullfile(inputFolder, filename));
    Elec_Raw = rot90(double(Full.y(:, :, 5)));
    Topo     = rot90(double(Full.y(:, :, 1)));
    if ~isequal(size(Elec_Raw), size(Topo))
        Elec_Raw = imresize(Elec_Raw, size(Topo));
    end

    Elec_norm = (Elec_Raw - median(Elec_Raw(:))) / mad(Elec_Raw(:), 1);
    Topo_norm = (Topo     - median(Topo(:)))     / mad(Topo(:), 1);
    ruido_norm = std(Elec_norm(:), 1);

    [Gy, Gx]  = gradient(Topo_norm);
    X         = [Topo_norm(:), Gx(:), Gy(:), ones(numel(Topo_norm), 1)];
    beta      = X \ Elec_norm(:);
    Elec_corr = Elec_norm - reshape(X * beta, size(Elec_norm));
    ruido_no_cross = std(Elec_corr(:), 1);

    corr_pre_T  = safe_corr(Elec_norm(:),  Topo_norm(:));
    corr_res_T  = safe_corr(Elec_corr(:),  Topo_norm(:));
    corr_res_Gx = safe_corr(Elec_corr(:),  Gx(:));
    corr_res_Gy = safe_corr(Elec_corr(:),  Gy(:));

    [Elec_syp1, pct_SyP1] = syp_selectivo(Elec_corr, [5 5], 3);
    ruido_no_syp1 = std(Elec_syp1(:), 1);

    medias_pre     = mean(Elec_syp1, 2);
    var_filas_pre  = var(medias_pre);
    Elec_strip     = line_strip(Elec_syp1);
    medias_post    = mean(Elec_strip, 2);
    var_filas_post = var(medias_post);
    ruido_no_strip = std(Elec_strip(:), 1);

    [Elec_clean, pct_SyP2] = syp_selectivo(Elec_strip, [5 1], 2);
    ruido_no_syp2 = std(Elec_clean(:), 1);

    Eseg = rescale_1_99(Elec_clean);

    preRow = sprintf(['%s,'...
        '%.6e,%.6e,%.6e,%.6e,%.6e,'...
        '%.6e,%.6e,%.6e,%.6e,'...
        '%.6e,%.6e,%.6e,%.6e\n'], ...
        filename, ...
        ruido_norm, ruido_no_cross, ruido_no_syp1, ruido_no_strip, ruido_no_syp2, ...
        corr_pre_T, corr_res_T, corr_res_Gx, corr_res_Gy, ...
        pct_SyP1, pct_SyP2, var_filas_pre, var_filas_post);
end


function cache = precalcular_mascaras(Eseg, sens_grid, otsu_grid, ...
                                       vR_grid, vL_grid, ...
                                       fb_sens, fb_vL, fb_pmin)
    nS = length(sens_grid);
    nM = length(otsu_grid);
    nR = length(vR_grid);
    nL = length(vL_grid);

    cache.BW1_raw = cell(nM, 1);
    for mi = 1:nM
        thresh = multithresh(Eseg, otsu_grid(mi));
        cache.BW1_raw{mi} = Eseg >= thresh(1);
    end

    cache.BW_reg = cell(nS, nR);
    for si = 1:nS
        for ri = 1:nR
            T = adaptthresh(Eseg, sens_grid(si), ...
                'NeighborhoodSize',   [vR_grid(ri) vR_grid(ri)], ...
                'Statistic',          'gaussian', ...
                'ForegroundPolarity', 'bright');
            cache.BW_reg{si, ri} = imbinarize(Eseg, T);
        end
    end

    cache.BW_loc = cell(nS, nL);
    for si = 1:nS
        for li = 1:nL
            T = adaptthresh(Eseg, sens_grid(si), ...
                'NeighborhoodSize',   [vL_grid(li) vL_grid(li)], ...
                'Statistic',          'gaussian', ...
                'ForegroundPolarity', 'bright');
            cache.BW_loc{si, li} = imbinarize(Eseg, T);
        end
    end

    T_fb = adaptthresh(Eseg, fb_sens, ...
        'NeighborhoodSize',   [fb_vL fb_vL], ...
        'Statistic',          'gaussian', ...
        'ForegroundPolarity', 'bright');
    cache.BW_fallback_fijo = bwareaopen(imbinarize(Eseg, T_fb), fb_pmin);
end


function fila = evaluar_configuracion(cache, cfg, filename, ...
                                       sens_grid, otsu_grid, ...
                                       vR_grid, vL_grid, ...
                                       fallback_mode)
    sens  = cfg(1);
    pmin  = cfg(2);
    ufb   = cfg(3);
    otsuK = cfg(4);
    vR    = cfg(5);
    vL    = cfg(6);

    si = find(sens_grid == sens,  1);
    mi = find(otsu_grid == otsuK, 1);
    ri = find(vR_grid   == vR,    1);
    li = find(vL_grid   == vL,    1);

    BW1_raw = cache.BW1_raw{mi};
    BW_reg  = cache.BW_reg{si, ri};
    BW_loc  = cache.BW_loc{si, li};

    BW_triple    = bwareaopen(BW1_raw & BW_reg & BW_loc, pmin);
    cov_triple   = sum(BW_triple(:)) / numel(BW_triple);
    islas_triple = numero_componentes(BW_triple);

    BW_solo    = bwareaopen(BW_loc, pmin);
    cov_solo   = sum(BW_solo(:)) / numel(BW_solo);
    islas_solo = numero_componentes(BW_solo);

    BW_gl    = bwareaopen(BW1_raw & BW_loc, pmin);
    cov_gl   = sum(BW_gl(:)) / numel(BW_gl);
    islas_gl = numero_componentes(BW_gl);

    fallback_activado = 0;
    if cov_triple < ufb
        fallback_activado = 1;
        if strcmp(fallback_mode, 'fixed')
            BW_final = cache.BW_fallback_fijo;
        else
            BW_final = bwareaopen(BW_loc, pmin);
        end
    else
        BW_final = BW_triple;
    end
    cov_final   = sum(BW_final(:)) / numel(BW_final);
    islas_final = numero_componentes(BW_final);
    if cov_final > 0
        FN_final = islas_final / cov_final;
    else
        FN_final = NaN;
    end

    fila = sprintf(['%s,'...
        '%.2f,%d,%.2f,%d,%d,%d,'...
        '%.6f,%d,'...
        '%.6f,%d,'...
        '%.6f,%d,'...
        '%.6f,%d,%.4f,%d\n'], ...
        filename, ...
        sens, pmin, ufb, otsuK, vR, vL, ...
        cov_triple, islas_triple, ...
        cov_solo,   islas_solo, ...
        cov_gl,     islas_gl, ...
        cov_final,  islas_final, FN_final, fallback_activado);
end


function n = numero_componentes(BW)
    CC = bwconncomp(BW);
    n  = CC.NumObjects;
end

function r = safe_corr(a, b)
    if std(a) == 0 || std(b) == 0
        r = NaN; return;
    end
    c = corrcoef(a, b);
    r = c(1, 2);
end

function [I_out, pct] = syp_selectivo(I_in, kernel, n)
    M     = medfilt2(I_in, kernel);
    R     = abs(I_in - M);
    sigma = median(R(:)) / 0.6745;
    if sigma == 0, sigma = eps; end
    mask  = R > n * sigma;
    pct   = sum(mask(:)) / numel(mask);
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

function escribir_pre_csv(outputCSV, preResults)
    fid = fopen(outputCSV, 'w');
    fprintf(fid, ['imagen,'...
        'ruido_norm,ruido_no_cross,ruido_no_syp1,ruido_no_strip,ruido_no_syp2,'...
        'corr_pre_T,corr_res_T,corr_res_Gx,corr_res_Gy,'...
        'pct_SyP1,pct_SyP2,var_filas_pre,var_filas_post\n']);
    for k = 1:length(preResults)
        if ~isempty(preResults{k})
            fprintf(fid, '%s', preResults{k});
        end
    end
    fclose(fid);
end

function escribir_bar_csv(outputCSV, barResults)
    fid = fopen(outputCSV, 'w');
    fprintf(fid, ['imagen,'...
        'sensibilidad,pix_minimos,umbral_fallback,otsu_k,ventana_regional,ventana_local,'...
        'cov_TripleAND,islas_TripleAND,'...
        'cov_SoloLocal,islas_SoloLocal,'...
        'cov_GlobalLocal,islas_GlobalLocal,'...
        'cov_FINAL,islas_FINAL,FN_FINAL,fallback_activado\n']);
    for k = 1:length(barResults)
        filas = barResults{k};
        if isempty(filas), continue; end
        for c = 1:length(filas)
            if ~isempty(filas{c})
                fprintf(fid, '%s', filas{c});
            end
        end
    end
    fclose(fid);
end
