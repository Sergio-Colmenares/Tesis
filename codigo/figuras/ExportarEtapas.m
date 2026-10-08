function ExportarResultados()
% =========================================================================
% ExportarResultados.m — Pipeline + exportación PDF + estadísticas
%
% Adaptado de ExportarEtapas.m. Genera tres salidas:
%
%   1. PDFs individuales (anexos)
%        outputFolder/<etapa>/<fab>/<imagen>.pdf
%        Las 81 imágenes en cada una de las 9 etapas del pipeline.
%
%   2. Grids 3x3 por etapa para la fabricación destacada (resultados)
%        gridFolder/<etapa>_<fab_destacada>.pdf
%        Réplicas en filas, posiciones en columnas.
%
%   3. CSV de estadísticas por imagen + agregados por set y global
%        statsCSV
%        81 filas individuales + 9 filas SET_<fab> + 1 fila GLOBAL.
%
% Métricas reportadas (alineadas con la sección de Validación):
%   - corr_elec_topo_raw / corr_elec_topo_post : correlación crosstalk
%   - pct_syp1 / pct_syp2                      : % píxeles modificados
%   - var_rows_pre / var_rows_post             : varianza entre filas
%   - cov_bw2 / cov_bw2c                       : cobertura de máscaras
%   - n_comp_bw2 / n_comp_bw2c                 : componentes conexas
%   - skel_px                                  : longitud del esqueleto
%
% Salida visual: P1-P99 individual por imagen para etapas continuas;
% [0 1] fijo para etapas binarias.
% =========================================================================
clear; clc; close all;

% -------------------------------------------------------------------------
% CONFIGURACIÓN
% -------------------------------------------------------------------------
rutas = rutas_tesis();   % rutas relativas al repositorio (codigo/utils)
inputFolder     = rutas.crudos;
colormapMATpath = rutas.colormap;
outputFolder    = fullfile(rutas.resultados, 'anexos');
gridFolder      = fullfile(rutas.resultados, 'grids');
statsCSV        = fullfile(rutas.resultados, 'stats_etapas.csv');

% Fabricación destacada para los grids 3x3 del informe
% Modificar tras inspeccionar la calidad visual del set.
fab_destacada = '2b';

% Parámetros del pipeline (alineados con Main.m)
sensibilidad = 0.55;
pix_minimos  = 50;

% -------------------------------------------------------------------------
% INICIALIZACIÓN
% -------------------------------------------------------------------------
if exist(colormapMATpath, 'file')
    S = load(colormapMATpath);
    names = fieldnames(S);
    cmap_continuo = S.(names{1});
else
    cmap_continuo = parula(256);
    warning('Colormap no encontrado, usando parula.');
end
cmap_binario = [0 0 0; 1 1 1];

% Etapas: clave (válida como campo de struct), nombre de carpeta, ¿binaria?
etapas_keys = {'raw','crosstalk','syp5x5','artefactos','syp5x1', ...
               'norm','bw2','bw2closed','skel'};
etapas_dirs = {'1_raw','2_crosstalk','3_syp5x5','4_artefactos','5_syp5x1', ...
               '6_norm','7_bw2','8_bw2closed','9_skel'};
es_binaria  = [false false false false false false true true true];

fabricaciones = {'0a','0b','0c','1a','1b','1c','2a','2b','2c'};

% Crear carpetas de salida
for e = 1:length(etapas_dirs)
    for f = 1:length(fabricaciones)
        d = fullfile(outputFolder, etapas_dirs{e}, fabricaciones{f});
        if ~exist(d, 'dir'), mkdir(d); end
    end
end
if ~exist(gridFolder, 'dir'), mkdir(gridFolder); end
sd = fileparts(statsCSV);
if ~exist(sd, 'dir'), mkdir(sd); end

% Buffer 3x3 para la fabricación destacada (réplica x posición)
buf = struct();
for e = 1:length(etapas_keys)
    buf.(etapas_keys{e}) = cell(3, 3);
end

% Acumulador de estadísticas
stats_rows = {};

% -------------------------------------------------------------------------
% BUCLE PRINCIPAL
% -------------------------------------------------------------------------
ibwFiles = dir(fullfile(inputFolder, '*.ibw'));
fprintf('Procesando %d imágenes...\n\n', length(ibwFiles));

for k = 1:length(ibwFiles)
    filename = ibwFiles(k).name;
    [~, nombre, ~] = fileparts(filename);

    tok = regexp(nombre, '^([0-2][abc])-([1-9])$', 'tokens');
    if isempty(tok)
        warning('Nombre no reconocido: %s — omitido.', filename);
        continue;
    end
    fab      = tok{1}{1};
    img_num  = str2double(tok{1}{2});
    replica  = ceil(img_num / 3);
    posicion = mod(img_num - 1, 3) + 1;

    try
        % ---- LECTURA -----------------------------------------------------
        Full_data = IBWread(fullfile(inputFolder, filename));
        Elec_Raw  = rot90(double(Full_data.y(:,:,5)));
        Topo      = rot90(double(Full_data.y(:,:,1)));
        if ~isequal(size(Elec_Raw), size(Topo))
            Elec_Raw = imresize(Elec_Raw, size(Topo));
        end

        % ---- ETAPA 1: RAW ------------------------------------------------
        guardar_pdf(Elec_Raw, cmap_continuo, ...
            fullfile(outputFolder, '1_raw', fab, [nombre '.pdf']), false);

        R = corrcoef(Elec_Raw(:), Topo(:));
        corr_raw = R(1, 2);

        % ---- ETAPA 2: CROSSTALK -----------------------------------------
        Elec_norm = (Elec_Raw - median(Elec_Raw(:))) / mad(Elec_Raw(:), 1);
        Topo_norm = (Topo     - median(Topo(:)))     / mad(Topo(:),     1);

        [Gy, Gx]  = gradient(Topo_norm);
        X         = [Topo_norm(:), Gx(:), Gy(:), ones(numel(Topo_norm), 1)];
        beta      = X \ Elec_norm(:);
        Elec_fit  = reshape(X * beta, size(Elec_norm));
        Elec_corr = Elec_norm - Elec_fit;

        guardar_pdf(Elec_corr, cmap_continuo, ...
            fullfile(outputFolder, '2_crosstalk', fab, [nombre '.pdf']), false);

        R = corrcoef(Elec_corr(:), Topo_norm(:));
        corr_post = R(1, 2);

        % Coeficiente de correlación múltiple del modelo completo
        % (T, dT/dx, dT/dy): fracción de la variación del canal eléctrico
        % explicada por la topografía. R_mult >= |corr_raw| siempre.
        e_c    = Elec_norm(:) - mean(Elec_norm(:));
        R_mult = sqrt(max(0, 1 - sum(Elec_corr(:).^2) / sum(e_c.^2)));

        % ---- ETAPA 3: SyP 5x5 -------------------------------------------
        [Elec_c1, mask_syp1] = SyP_Selectivo_Mask(Elec_corr, [5 5], 3);

        guardar_pdf(Elec_c1, cmap_continuo, ...
            fullfile(outputFolder, '3_syp5x5', fab, [nombre '.pdf']), false);

        pct_syp1     = 100 * sum(mask_syp1(:)) / numel(mask_syp1);
        var_rows_pre = var(mean(Elec_c1, 2));

        % ---- ETAPA 4: ARTEFACTOS ----------------------------------------
        Elec_str = line_strip_correction(Elec_c1);

        guardar_pdf(Elec_str, cmap_continuo, ...
            fullfile(outputFolder, '4_artefactos', fab, [nombre '.pdf']), false);

        var_rows_post = var(mean(Elec_str, 2));

        % ---- ETAPA 5: SyP 5x1 -------------------------------------------
        [Elec_cln, mask_syp2] = SyP_Selectivo_Mask(Elec_str, [5 1], 2);

        guardar_pdf(Elec_cln, cmap_continuo, ...
            fullfile(outputFolder, '5_syp5x1', fab, [nombre '.pdf']), false);

        pct_syp2 = 100 * sum(mask_syp2(:)) / numel(mask_syp2);

        % ---- ETAPA 6: NORMALIZACIÓN -------------------------------------
        Eseg = rescale_1_99(Elec_cln);

        guardar_pdf(Eseg, cmap_continuo, ...
            fullfile(outputFolder, '6_norm', fab, [nombre '.pdf']), false);

        % ---- BINARIZACIÓN ------------------------------------------------
        thresh      = multithresh(Eseg, 6);
        BW1         = bwareaopen(Eseg >= thresh(1), pix_minimos);

        T_regional  = adaptthresh(Eseg, sensibilidad, ...
            'NeighborhoodSize',[51 51], 'Statistic','gaussian', ...
            'ForegroundPolarity','bright');
        BW_regional = imbinarize(Eseg, T_regional);

        T_local     = adaptthresh(Eseg, sensibilidad, ...
            'NeighborhoodSize',[21 21], 'Statistic','gaussian', ...
            'ForegroundPolarity','bright');
        BW_local    = imbinarize(Eseg, T_local);

        BW2       = bwareaopen(BW1 & BW_regional & BW_local, pix_minimos);
        cobertura = sum(BW2(:)) / numel(BW2);

        if cobertura < 0.15
            T_fb = adaptthresh(Eseg, sensibilidad, ...
                'NeighborhoodSize',[21 21], 'Statistic','gaussian', ...
                'ForegroundPolarity','bright');
            BW2 = bwareaopen(imbinarize(Eseg, T_fb), pix_minimos);
        end

        % ---- ETAPA 7: BW2 (estricta) ------------------------------------
        guardar_pdf(double(BW2), cmap_binario, ...
            fullfile(outputFolder, '7_bw2', fab, [nombre '.pdf']), true);

        cov_bw2    = sum(BW2(:)) / numel(BW2);
        n_comp_bw2 = bwconncomp(BW2).NumObjects;

        % ---- ETAPA 8: BW2_closed (morfológica) --------------------------
        BW2_closed = imclose(BW2, strel('disk', 3));

        guardar_pdf(double(BW2_closed), cmap_binario, ...
            fullfile(outputFolder, '8_bw2closed', fab, [nombre '.pdf']), true);

        cov_bw2c    = sum(BW2_closed(:)) / numel(BW2_closed);
        n_comp_bw2c = bwconncomp(BW2_closed).NumObjects;

        % ---- ETAPA 9: ESQUELETO -----------------------------------------
        BW_skel = bwmorph(bwskel(BW2_closed), 'spur', 5);

        guardar_pdf(double(BW_skel), cmap_binario, ...
            fullfile(outputFolder, '9_skel', fab, [nombre '.pdf']), true);

        skel_px = sum(BW_skel(:));

        % ---- BUFFER GRID DESTACADA --------------------------------------
        if strcmp(fab, fab_destacada)
            buf.raw       {replica, posicion} = Elec_Raw;
            buf.crosstalk {replica, posicion} = Elec_corr;
            buf.syp5x5    {replica, posicion} = Elec_c1;
            buf.artefactos{replica, posicion} = Elec_str;
            buf.syp5x1    {replica, posicion} = Elec_cln;
            buf.norm      {replica, posicion} = Eseg;
            buf.bw2       {replica, posicion} = double(BW2);
            buf.bw2closed {replica, posicion} = double(BW2_closed);
            buf.skel      {replica, posicion} = double(BW_skel);
        end

        % ---- ACUMULAR STATS ---------------------------------------------
        stats_rows(end+1, :) = {nombre, fab, replica, posicion, ...
            corr_raw, corr_post, R_mult, pct_syp1, ...
            var_rows_pre, var_rows_post, pct_syp2, ...
            cov_bw2, n_comp_bw2, cov_bw2c, n_comp_bw2c, skel_px}; %#ok<AGROW>

        fprintf('[%d/%d] %s\n', k, length(ibwFiles), filename);

    catch ME
        fprintf('  ERROR en %s: %s\n', filename, ME.message);
    end
end

% -------------------------------------------------------------------------
% GRIDS 3x3 PARA LA FABRICACIÓN DESTACADA
% -------------------------------------------------------------------------
fprintf('\nGenerando grids 3x3 para fabricación %s...\n', fab_destacada);
for e = 1:length(etapas_keys)
    grid_data = buf.(etapas_keys{e});
    if all(cellfun(@isempty, grid_data(:)))
        warning('Sin datos para grid de %s — omitido.', etapas_keys{e});
        continue;
    end
    output_path = fullfile(gridFolder, ...
        sprintf('%s_%s.pdf', etapas_dirs{e}, fab_destacada));
    if es_binaria(e), cmap_use = cmap_binario; else, cmap_use = cmap_continuo; end
    generar_grid_3x3(grid_data, cmap_use, output_path, es_binaria(e));
end

% -------------------------------------------------------------------------
% EXPORTACIÓN DE ESTADÍSTICAS (imágenes + agregados por set + global)
% -------------------------------------------------------------------------
header = {'imagen','fabricacion','replica','posicion', ...
    'corr_elec_topo_raw','corr_elec_topo_post','R_multiple_crosstalk', ...
    'pct_syp1','var_rows_pre','var_rows_post','pct_syp2', ...
    'cov_bw2','n_comp_bw2','cov_bw2c','n_comp_bw2c','skel_px'};

T = cell2table(stats_rows, 'VariableNames', header);

% Agregados por set
sets_unique = unique(T.fabricacion);
agg_rows = {};
for i = 1:length(sets_unique)
    Ts = T(strcmp(T.fabricacion, sets_unique{i}), :);
    means = varfun(@mean, Ts(:, 5:end), 'OutputFormat', 'table');
    means.Properties.VariableNames = T.Properties.VariableNames(5:end);
    agg_rows(end+1, :) = [{['SET_' sets_unique{i}], sets_unique{i}, NaN, NaN}, ...
        table2cell(means)]; %#ok<AGROW>
end

% Agregado global
means_global = varfun(@mean, T(:, 5:end), 'OutputFormat', 'table');
means_global.Properties.VariableNames = T.Properties.VariableNames(5:end);
agg_rows(end+1, :) = [{'GLOBAL', '-', NaN, NaN}, table2cell(means_global)];

T_agg  = cell2table(agg_rows, 'VariableNames', header);
T_full = [T; T_agg];

setenv('LC_NUMERIC','C');
writetable(T_full, statsCSV);

fprintf('\nStats exportadas → %s\n', statsCSV);
fprintf('PDFs individuales → %s\n', outputFolder);
fprintf('Grids 3x3 → %s\n', gridFolder);
end


% =========================================================================
% FUNCIONES DE EXPORTACIÓN
% =========================================================================

function guardar_pdf(img, cmap, filepath, esbin)
% Exporta una imagen como PDF (raster embebido, vectorialmente envuelto).
% Continuas: P1-P99 individual. Binarias: [0 1] fijo.

    fig = figure('Visible','off','Units','pixels','Position',[0 0 512 512]);
    ax  = axes(fig, 'Position',[0 0 1 1], 'Units','normalized');

    if esbin
        img_vis = img;
    else
        img_vis = normalizar_p1_p99(img);
    end

    imagesc(ax, img_vis);
    colormap(ax, cmap);
    clim(ax, [0 1]);
    axis(ax, 'image', 'off');

    set(fig, 'Renderer', 'opengl');
    exportgraphics(fig, filepath, 'ContentType','image', 'Resolution', 300);
    close(fig);
end


function generar_grid_3x3(grid_data, cmap, filepath, esbin)
% Genera un PDF con un grid 3x3 (réplicas en filas, posiciones en columnas).
% Cada celda continua se normaliza P1-P99 individualmente para preservar
% el contraste local de cada imagen del set.

    fig = figure('Visible','off','Units','pixels','Position',[0 0 1536 1536]);
    tl  = tiledlayout(fig, 3, 3, 'TileSpacing','none', 'Padding','none');

    for r = 1:3
        for p = 1:3
            ax  = nexttile(tl);
            img = grid_data{r, p};
            if isempty(img)
                axis(ax, 'off');
                continue;
            end
            if esbin
                img_vis = img;
            else
                img_vis = normalizar_p1_p99(img);
            end
            imagesc(ax, img_vis);
            colormap(ax, cmap);
            clim(ax, [0 1]);
            axis(ax, 'image', 'off');
        end
    end

    set(fig, 'Renderer','opengl');
    exportgraphics(fig, filepath, 'ContentType','image', 'Resolution', 200);
    close(fig);
end


function img_vis = normalizar_p1_p99(img)
% Normalización P1-P99 individual con saturación a [0 1].
    lim_inf = prctile(img(:), 1);
    lim_sup = prctile(img(:), 99);
    if lim_sup > lim_inf
        img_vis = (img - lim_inf) / (lim_sup - lim_inf);
        img_vis = max(0, min(1, img_vis));
    else
        img_vis = zeros(size(img));
    end
end


% =========================================================================
% PIPELINE — FUNCIONES AUXILIARES
% =========================================================================

function I_out = line_strip_correction(I_in)
    [r, ~] = size(I_in);
    I_out  = zeros(size(I_in));
    for i = 1:r
        row    = I_in(i, :);
        sigma  = mad(row, 1);
        dyn    = prctile(row, 95) - prctile(row, 5);
        ratio  = sigma / dyn;
        p      = max(25, min(45, 40 - 20*ratio));
        cutoff = prctile(row, p);
        bg_pix = row(row <= cutoff);
        if isempty(bg_pix)
            offset = median(row);
        else
            offset = median(bg_pix);
        end
        I_out(i, :) = row - offset;
    end
end


function [I_Out, Mascara_Malos] = SyP_Selectivo_Mask(I_In, kernel_size, n_sigmas)
% Variante de Etapa1_SyP_Selectivo que también devuelve la máscara
% de píxeles modificados, útil para reportar el % reemplazado.
    Fondo_Ref     = medfilt2(I_In, kernel_size);
    Residuo       = abs(I_In - Fondo_Ref);
    sigma_ruido   = median(Residuo(:)) / 0.6745;
    Mascara_Malos = Residuo > (n_sigmas * sigma_ruido);
    I_Out         = I_In;
    I_Out(Mascara_Malos) = Fondo_Ref(Mascara_Malos);
end


function Img_Vis = rescale_1_99(Data)
    lim_inf = prctile(Data(:), 1);
    lim_sup = prctile(Data(:), 99);
    if lim_sup == lim_inf
        Img_Vis = zeros(size(Data));
        return;
    end
    Img_Vis = (Data - lim_inf) / (lim_sup - lim_inf);
    Img_Vis(Img_Vis < 0) = 0;
    Img_Vis(Img_Vis > 1) = 1;
end
