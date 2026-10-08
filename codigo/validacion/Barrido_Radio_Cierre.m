function Barrido_Radio_Cierre()
% =========================================================================
% Barrido_Radio_Cierre.m  (versión final, fallback estandarizado)
%
% Justifica empíricamente la elección de r=3 px para el cierre morfológico
% que define M_mor. El fallback aplicado al construir M_e está
% estandarizado: reutiliza M_L del pipeline (sens=0.55, vL=21, pmin=50)
% en vez de calcular un M_L con parámetros distintos.
%
% Salida: barrido_radio_cierre55.csv -> 81 imágenes * 9 radios = 729 filas
% Tiempo estimado: ~10 min con 6 workers.
% =========================================================================

clear; clc; close all;

% -------------------------------------------------------------------------
% CONFIGURACIÓN
% -------------------------------------------------------------------------
rutas = rutas_tesis();   % rutas relativas al repositorio (codigo/utils)
inputFolder  = rutas.crudos;
outputCSV    = fullfile(rutas.resultados, 'barrido_radio_cierre55.csv');
nWorkers     = 6;

nm_por_pixel = 60000 / 1024;
r_grid       = [1, 2, 3, 4, 5, 6, 7, 8, 10];

% --- Configuración del pipeline elegido ---
pipe_sens = 0.55;
pipe_pmin = 50;
pipe_otsu = 6;
pipe_vR   = 51;
pipe_vL   = 21;
pipe_ufb  = 0.15;

% Poda del esqueleto (Main.m usa spur 5)
spur_iter = 5;

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
fprintf('Barrido sobre radio del cierre morfológico\n');
fprintf('================================================================\n');
fprintf('Imágenes        : %d\n', nImg);
fprintf('Radios          : %s\n', mat2str(r_grid));
fprintf('Pipeline        : sens=%.2f, pmin=%d, otsu=%d, vR=%d, vL=%d, ufb=%.2f\n', ...
        pipe_sens, pipe_pmin, pipe_otsu, pipe_vR, pipe_vL, pipe_ufb);
fprintf('Fallback        : reutiliza M_L del pipeline (estandarizado)\n');
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
nR = length(r_grid);
resultados = cell(nImg, 1);

parfor k = 1:nImg
    filename = fileNames{k};
    try
        Eseg = preprocesar(filename, inputFolder);

        % Construcción de M_e con la config del pipeline.
        % Fallback estandarizado: reutiliza M_L del Triple AND.
        [M_e, fallback_activado] = construir_Me(Eseg, ...
            pipe_sens, pipe_pmin, pipe_otsu, pipe_vR, pipe_vL, pipe_ufb);

        cov_Me = sum(M_e(:)) / numel(M_e);
        Nc_Me  = numero_componentes(M_e);

        filas = cell(nR, 1);
        for ri = 1:nR
            r = r_grid(ri);
            m = evaluar_radio(M_e, r, spur_iter);
            filas{ri} = sprintf(['%s,'...
                '%d,%.2f,'...
                '%.6f,%d,'...
                '%.6f,%d,'...
                '%.6f,%d,%.6f,'...
                '%d,%.6f,'...
                '%d,%.4f,%d\n'], ...
                filename, ...
                r, r * nm_por_pixel, ...
                cov_Me, Nc_Me, ...
                m.cov_mor, m.Nc_mor, ...
                m.delta_cov, m.delta_Nc, m.ratio_Nc, ...
                m.size_max, m.percolacion, ...
                m.skel_px, m.skel_um, ...
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
    'radio_px,radio_nm,'...
    'cov_Me,Nc_Me,'...
    'cov_Mmor,Nc_Mmor,'...
    'delta_cov,delta_Nc,ratio_Nc,'...
    'size_max_px,percolacion,'...
    'skel_px,skel_um,fallback_activado\n']);
for k = 1:nImg
    filas = resultados{k};
    if isempty(filas), continue; end
    for ri = 1:length(filas)
        if ~isempty(filas{ri})
            fprintf(fid, '%s', filas{ri});
        end
    end
end
fclose(fid);

fprintf('\nListo. CSV en: %s\n', outputCSV);
fprintf('================================================================\n');
end


% =========================================================================
% EVALUACIÓN DEL CIERRE PARA UN RADIO DADO
% =========================================================================
function m = evaluar_radio(M_e, r, spur_iter)
    se     = strel('disk', r);
    M_mor  = imclose(M_e, se);

    cov_Me  = sum(M_e(:))  / numel(M_e);
    cov_mor = sum(M_mor(:)) / numel(M_mor);

    CC_e   = bwconncomp(M_e);
    CC_mor = bwconncomp(M_mor);

    Nc_Me  = CC_e.NumObjects;
    Nc_mor = CC_mor.NumObjects;

    delta_cov = cov_mor - cov_Me;
    delta_Nc  = Nc_Me - Nc_mor;
    if Nc_Me > 0
        ratio_Nc = Nc_mor / Nc_Me;
    else
        ratio_Nc = NaN;
    end

    if Nc_mor == 0
        size_max    = 0;
        percolacion = 0;
    else
        sizes       = cellfun(@numel, CC_mor.PixelIdxList);
        size_max    = max(sizes);
        percolacion = size_max / sum(sizes);
    end

    BW_skel = bwmorph(bwskel(M_mor), 'spur', spur_iter);
    skel_px = sum(BW_skel(:));
    % Longitud física del esqueleto con la misma definición que el
    % descriptor network_length: pasos ortogonales con peso 1 y diagonales
    % (sin camino ortogonal alternativo) con peso sqrt(2).
    H_adj  = BW_skel(:,1:end-1) & BW_skel(:,2:end);
    V_adj  = BW_skel(1:end-1,:) & BW_skel(2:end,:);
    D1_adj = BW_skel(1:end-1,1:end-1) & BW_skel(2:end,2:end) & ...
             ~BW_skel(1:end-1,2:end)  & ~BW_skel(2:end,1:end-1);
    D2_adj = BW_skel(1:end-1,2:end)   & BW_skel(2:end,1:end-1) & ...
             ~BW_skel(1:end-1,1:end-1) & ~BW_skel(2:end,2:end);
    n_orto = nnz(H_adj) + nnz(V_adj);
    n_diag = nnz(D1_adj) + nnz(D2_adj);
    skel_um = (n_orto + sqrt(2)*n_diag) * (60000 / 1024) / 1000;

    m.cov_mor      = cov_mor;
    m.Nc_mor       = Nc_mor;
    m.delta_cov    = delta_cov;
    m.delta_Nc     = delta_Nc;
    m.ratio_Nc     = ratio_Nc;
    m.size_max     = size_max;
    m.percolacion  = percolacion;
    m.skel_px      = skel_px;
    m.skel_um      = skel_um;
end


% =========================================================================
% CONSTRUCCIÓN DE M_e CON FALLBACK ESTANDARIZADO
% El fallback reutiliza BW_loc (M_L del pipeline) en vez de calcular un
% M_L con parámetros distintos.
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
% PREPROCESAMIENTO (idéntico al Main.m)
% =========================================================================
function Eseg = preprocesar(filename, inputFolder)
    Full     = IBWread(fullfile(inputFolder, filename));
    Elec_Raw = rot90(double(Full.y(:, :, 5)));
    Topo     = rot90(double(Full.y(:, :, 1)));
    if ~isequal(size(Elec_Raw), size(Topo))
        Elec_Raw = imresize(Elec_Raw, size(Topo));
    end

    Elec_norm = (Elec_Raw - median(Elec_Raw(:))) / mad(Elec_Raw(:), 1);
    Topo_norm = (Topo     - median(Topo(:)))     / mad(Topo(:), 1);

    [Gy, Gx] = gradient(Topo_norm);
    X        = [Topo_norm(:), Gx(:), Gy(:), ones(numel(Topo_norm), 1)];
    beta     = X \ Elec_norm(:);
    Elec_corr = Elec_norm - reshape(X * beta, size(Elec_norm));

    Elec_syp1  = syp_selectivo(Elec_corr, [5 5], 3);
    Elec_strip = line_strip(Elec_syp1);
    Elec_clean = syp_selectivo(Elec_strip, [5 1], 2);
    Eseg       = rescale_1_99(Elec_clean);
end


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
