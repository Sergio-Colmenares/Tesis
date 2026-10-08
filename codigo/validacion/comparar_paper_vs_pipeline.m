function comparar_paper_vs_pipeline()
% =========================================================================
% comparar_paper_vs_pipeline.m
%
% Objetivo: aislar la causa de que la tendencia CNTS-vs-voltaje del paper
% [Castaneda-Uribe & Avila, 2020] NO aparezca en tu dataset.
%
% Para cada imagen .ibw calcula CNTD/CNTA/CNTS con TRES binarizaciones,
% manteniendo idéntico todo lo demás (misma señal de entrada, mismas líneas
% de barrido por la semilla fija, misma lógica de descriptores):
%
%   (1) PIPELINE        -> tu binarización multiescala (BW2_closed).
%   (2) PAPER_FIEL      -> método del paper tal cual: escala de grises ->
%                          CLAHE (adapthisteq) -> mediana -> umbral 75% del
%                          máximo, aplicado a la señal eléctrica CRUDA.
%   (3) PAPER_CONTROL   -> solo el umbral 75% del paper, pero aplicado a TU
%                          señal preprocesada Eseg. Aísla el efecto de la
%                          binarización manteniendo fijo el preprocesamiento.
%
% Lectura del resultado:
%   - Si la tendencia CNTS↓ con el voltaje aparece en (2) y/o (3) pero NO en
%     (1)  -> la causa es tu pipeline (lo barre).
%   - Si NO aparece en ninguna de las tres -> la causa son las muestras /
%     el ruido de fabricación (señal < ruido), no el método.
%
% Salida:
%   - CSV  comparacion_binarizacion.csv  (CNTD/CNTA/CNTS x3 por imagen)
%   - Tabla por consola con CNTS medio por voltaje a 10 Hz (lo comparable
%     al paper) para los tres métodos.
%
% NOTA: reutiliza tu función IBWread (debe estar en el path, igual que en
% Main.m). Los parámetros del pipeline se fijan a los de tu Main.m.
% =========================================================================

clear; clc;

% ----------------------------- CONFIG -----------------------------------
rutas = rutas_tesis();   % rutas relativas al repositorio (codigo/utils)
inputFolder  = rutas.crudos;
outputCSV    = fullfile(rutas.resultados, 'comparacion_binarizacion.csv');

nm_por_pixel = 60000 / 1024;     % 58.59 nm/px
alpha        = 2000;             % longitud máx de un SWCNT individual [nm]
sensibilidad = 0.55;             % parámetros del pipeline (= Main.m)
pix_minimos  = 50;
ventana_grad = 50;

% Para el método del paper: ¿aplicar la misma apertura por área (pix_minimos)
% que usa tu pipeline? El paper NO lo hace (solo umbraliza). Por defecto OFF
% para ser fiel; ponlo en true si el ruido de un solo píxel domina.
paper_area_open = false;

% ------------------------------------------------------------------------
ibwFiles  = dir(fullfile(inputFolder,'*.ibw'));
outputDir = fileparts(outputCSV);
if ~exist(outputDir,'dir'), mkdir(outputDir); end

fid = fopen(outputCSV,'w');
fprintf(fid, ['imagen,voltaje_V,frecuencia_Hz,replica,posicion,'...
    'CNTD_pipeline,CNTA_pipeline,CNTS_pipeline,'...
    'CNTD_paperFiel,CNTA_paperFiel,CNTS_paperFiel,'...
    'CNTD_paperCtrl,CNTA_paperCtrl,CNTS_paperCtrl\n']);

% acumuladores para el resumen (solo 10 Hz)
res = struct('v',[],'f',[],'cs_pipe',[],'cs_pf',[],'cs_pc',[]);

for k = 1:numel(ibwFiles)
    try
        filename  = ibwFiles(k).name;
        Full_data = IBWread(fullfile(inputFolder, filename));
        Elec_Raw  = rot90(double(Full_data.y(:,:,5)));
        Topo      = rot90(double(Full_data.y(:,:,1)));
        if ~isequal(size(Elec_Raw), size(Topo))
            Elec_Raw = imresize(Elec_Raw, size(Topo));
        end

        % (1) Tu pipeline -> BW2_closed y, de paso, la señal Eseg
        [BW_pipeline, Eseg] = binariza_pipeline(Elec_Raw, Topo, sensibilidad, pix_minimos);

        % (2) Paper fiel: CLAHE + mediana + 75% sobre la señal CRUDA
        BW_paperFiel = binariza_paper(Elec_Raw, true, paper_area_open, pix_minimos);

        % (3) Paper controlado: solo umbral 75% sobre TU Eseg (sin CLAHE,
        %     porque Eseg ya está normalizada; aísla la binarización)
        BW_paperCtrl = binariza_paper(Eseg, false, paper_area_open, pix_minimos);

        % Descriptores espaciales con la MISMA lógica para las tres máscaras
        [D1,A1,S1] = descriptores_espaciales(BW_pipeline,  nm_por_pixel, alpha);
        [D2,A2,S2] = descriptores_espaciales(BW_paperFiel, nm_por_pixel, alpha);
        [D3,A3,S3] = descriptores_espaciales(BW_paperCtrl, nm_por_pixel, alpha);

        [vV, fHz, rep, pos] = parsear_fabricacion(filename);

        fprintf(fid, ['%s,%g,%g,%d,%d,'...
            '%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e\n'], ...
            filename, vV, fHz, rep, pos, ...
            D1,A1,S1, D2,A2,S2, D3,A3,S3);

        if fHz == 10
            res.v(end+1)=vV; res.cs_pipe(end+1)=S1; res.cs_pf(end+1)=S2; res.cs_pc(end+1)=S3; %#ok<AGROW>
        end

        fprintf('Procesado %d/%d: %s\n', k, numel(ibwFiles), filename);
    catch ME
        fprintf('Error en %s: %s\n', filename, ME.message);
    end
end
fclose(fid);

% ----------------------------- RESUMEN ----------------------------------
fprintf('\n==============================================================\n');
fprintf(' CNTS medio por VOLTAJE a 10 Hz (lo comparable al paper)\n');
fprintf('==============================================================\n');
fprintf(' %-6s | %-12s | %-12s | %-12s\n','Volt','PIPELINE','PAPER_FIEL','PAPER_CTRL');
fprintf(' ------ | ------------ | ------------ | ------------\n');
for v = [5 10 15]
    m = res.v==v;
    fprintf(' %4d V | %12.2f | %12.2f | %12.2f\n', v, ...
        mean(res.cs_pipe(m)), mean(res.cs_pf(m)), mean(res.cs_pc(m)));
end
fprintf('\n Paper original (CNTS): 5V=2.2  10V=2.0  15V=1.7  (0V ref=1.5)\n');
fprintf(' -> ¿Alguna columna reproduce el descenso 2.2 -> 2.0 -> 1.7?\n');
fprintf('==============================================================\n');
fprintf('CSV -> %s\n', outputCSV);
end


% =========================================================================
% BINARIZACIÓN DEL PAPER  [Castaneda-Uribe & Avila, 2020, Exp. Section]
% "grayscale -> adaptive histogram equalization -> median filter ->
%  binarize: pixels > 75% of the maximum value -> 1, else 0"
% =========================================================================
function BW = binariza_paper(img_in, do_clahe, do_area_open, pix_minimos)
    % 1) Escala de grises [0,1]
    G = mat2gray(img_in);
    % 2) Ecualización adaptativa de histograma (CLAHE)
    if do_clahe
        G = adapthisteq(G);          % defaults: 8x8 tiles, cliplimit 0.01
    end
    % 3) Filtro de mediana (ruido de crosstalk del AFM, según el paper)
    G = medfilt2(G, [3 3]);
    % 4) Umbral al 75% del valor máximo
    BW = G > (0.75 * max(G(:)));
    % (opcional) limpieza por área — el paper NO la aplica
    if do_area_open
        BW = bwareaopen(BW, pix_minimos);
    end
end


% =========================================================================
% TU PIPELINE MULTIESCALA (extraído de Main.m, sin cambios de lógica).
% Devuelve la máscara morfológica BW2_closed y la señal normalizada Eseg.
% =========================================================================
function [BW2_closed, Eseg] = binariza_pipeline(Elec_Raw, Topo, sensibilidad, pix_minimos)
    % --- Corrección de crosstalk topográfico (regresión lineal múltiple) ---
    Elec_norm = (Elec_Raw - median(Elec_Raw(:))) / mad(Elec_Raw(:),1);
    Topo_norm = (Topo     - median(Topo(:)))     / mad(Topo(:),1);
    [Gy, Gx]  = gradient(Topo_norm);
    X         = [Topo_norm(:), Gx(:), Gy(:), ones(numel(Topo_norm),1)];
    beta      = X \ Elec_norm(:);
    Elec_fit  = reshape(X*beta, size(Elec_norm));

    % --- Limpieza y normalización ---
    Elec_corr = Elec_norm - Elec_fit;
    Elec_c1   = Etapa1_SyP_Selectivo(Elec_corr, [5 5], 3);
    Elec_str  = line_strip_correction(Elec_c1);
    Elec_cln  = Etapa1_SyP_Selectivo(Elec_str,  [5 1], 2);
    Eseg      = rescale_1_99(Elec_cln);

    % --- Triple binarización ---
    thresh      = multithresh(Eseg, 6);
    BW1         = bwareaopen(Eseg >= thresh(1), pix_minimos);
    T_regional  = adaptthresh(Eseg, sensibilidad, 'NeighborhoodSize',[51 51], ...
                    'Statistic','gaussian','ForegroundPolarity','bright');
    BW_regional = imbinarize(Eseg, T_regional);
    T_local     = adaptthresh(Eseg, sensibilidad, 'NeighborhoodSize',[21 21], ...
                    'Statistic','gaussian','ForegroundPolarity','bright');
    BW_local    = imbinarize(Eseg, T_local);

    BW2       = bwareaopen(BW1 & BW_regional & BW_local, pix_minimos);
    cobertura = sum(BW2(:)) / numel(BW2);

    % --- Respaldo si cobertura < 15% ---
    if cobertura < 0.15
        T_fb = adaptthresh(Eseg, 0.55, 'NeighborhoodSize',[21 21], ...
                 'Statistic','gaussian','ForegroundPolarity','bright');
        BW2  = bwareaopen(imbinarize(Eseg, T_fb), 50);
    end

    % --- Cierre morfológico r=3 ---
    BW2_closed = imclose(BW2, strel('disk', 3));
end


% =========================================================================
% DESCRIPTORES ESPACIALES (idéntico a GRUPO 1 de Main.m).
% Semilla fija -> mismas 100 líneas para CUALQUIER máscara de la misma imagen.
% =========================================================================
function [CNTD, CNTA, CNTS] = descriptores_espaciales(BW, nm_por_pixel, alpha)
    [nrows, ~] = size(BW);
    espaciados = [];
    tamanios   = [];

    rng(42);
    for ii = 1:100
        fila    = double(BW(randi(nrows), :));
        cambios = diff([0, fila, 0]);
        ini_cnt = find(cambios ==  1);
        fin_cnt = find(cambios == -1);
        if ~isempty(ini_cnt)
            tamanios = [tamanios, (fin_cnt - ini_cnt) * nm_por_pixel]; %#ok<AGROW>
        end
        if numel(ini_cnt) > 1
            for jj = 1:numel(ini_cnt)-1
                esp = (ini_cnt(jj+1) - fin_cnt(jj)) * nm_por_pixel;
                if esp > 0, espaciados = [espaciados, esp]; end %#ok<AGROW>
            end
        end
    end

    % CNTD: área bajo la PDF lognormal en η ± 20% (η = modo)
    esp_pos = espaciados(espaciados > 0);
    if numel(esp_pos) > 10
        try
            pd_esp = fitdist(esp_pos(:), 'Lognormal');
            eta    = exp(pd_esp.mu - pd_esp.sigma^2);
            CNTD   = cdf(pd_esp, 1.2*eta) - cdf(pd_esp, 0.8*eta);
        catch, CNTD = NaN; end
    else
        CNTD = NaN;
    end

    % CNTA: fracción de la PDF lognormal de tamaños por encima de alpha
    tam_pos = tamanios(tamanios > 0);
    if numel(tam_pos) > 10
        try
            pd_tam = fitdist(tam_pos(:), 'Lognormal');
            CNTA   = 1 - cdf(pd_tam, alpha);
            CNTA   = max(0, min(1, CNTA));
        catch, CNTA = NaN; end
    else
        CNTA = NaN;
    end

    % CNTS = CNTA / CNTD  (reproduce los valores tabulados del paper)
    if ~isnan(CNTD) && ~isnan(CNTA) && CNTD > 0
        CNTS = CNTA / CNTD;
    else
        CNTS = NaN;
    end
end


% =========================================================================
% AUXILIARES (copiadas de Main.m para que el script sea autocontenido)
% =========================================================================
function [voltaje_V, frecuencia_Hz, replica, posicion] = parsear_fabricacion(filename)
    voltaje_V = NaN; frecuencia_Hz = NaN; replica = NaN; posicion = NaN;
    [~, nombre, ~] = fileparts(filename);
    tok = regexp(nombre, '^([0-2])([abc])-([1-9])$', 'tokens');
    if isempty(tok)
        warning('Nombre no coincide con el formato esperado: %s', filename); return;
    end
    switch tok{1}{1}
        case '0', voltaje_V = 5;  case '1', voltaje_V = 10; case '2', voltaje_V = 15;
    end
    switch tok{1}{2}
        case 'a', frecuencia_Hz = 10; case 'b', frecuencia_Hz = 1000; case 'c', frecuencia_Hz = 100000;
    end
    img_num  = str2double(tok{1}{3});
    replica  = ceil(img_num / 3);
    posicion = mod(img_num - 1, 3) + 1;
end

function I_out = line_strip_correction(I_in)
    [r, ~] = size(I_in); I_out = zeros(size(I_in));
    for i = 1:r
        row    = I_in(i,:);
        sigma  = mad(row, 1);
        dyn    = prctile(row,95) - prctile(row,5);
        ratio  = sigma / dyn;
        p      = max(25, min(45, 40 - 20*ratio));
        cutoff = prctile(row, p);
        bg_pix = row(row <= cutoff);
        if isempty(bg_pix), offset = median(row); else, offset = median(bg_pix); end
        I_out(i,:) = row - offset;
    end
end

function I_Out = Etapa1_SyP_Selectivo(I_In, kernel_size, n_sigmas)
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
    if lim_sup == lim_inf, Img_Vis = zeros(size(Data)); return; end
    Img_Vis = (Data - lim_inf) / (lim_sup - lim_inf);
    Img_Vis(Img_Vis < 0) = 0; Img_Vis(Img_Vis > 1) = 1;
end
