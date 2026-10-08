function Main()
% =========================================================================
% Main.m — Extracción de descriptores morfológicos sobre imágenes KPFM
%
% Pipeline:
%   1. Lectura del .ibw → señales eléctrica (canal 5, Amplitude del 2do
%      armónico en metros tras la conversión AmpInvOLS del Asylum) y
%      topográfica (canal 1).
%   2. Corrección de crosstalk topográfico por regresión lineal múltiple.
%   3. Pipeline de binarización multiescala → BW2 estricta y BW2_closed.
%   4. Pipeline ELEC_B: corrección de crosstalk + corrección de rayas RLOESS
%      sobre la escala original (en metros) para los descriptores de
%      intensidad y perfil.
%   5. Extracción de 20 descriptores agrupados en 6 categorías.
%
% Unidades finales del CSV:
%   Distribución espacial : CNTD, CNTA, CNTS                  [adim.]
%   Intensidad            : intensidad_*_pm                   [pm]
%                           gradiente_medio_pm_nm             [pm/nm]
%   Forma                 : elongacion_media, tortuosidad_media [adim.]
%                           area_media_um2, area_std_um2      [μm²]
%   Orientación           : orient_dominante                  [°]
%                           coherencia                        [adim., 0-1]
%   Conectividad          : cobertura_total                   [adim., 0-1]
%                           indice_percolacion                [adim., 0-1]
%                           network_length_um                 [μm]
%                           num_fragmentos                    [conteo]
%   Perfil                : perfil_pendiente_pm_nm            [pm/nm]
%                           perfil_residuo_rms_pm             [pm]
%                           perfil_rango_pm                   [pm]
% =========================================================================

clear; clc; close all;

% -------------------------------------------------------------------------
% CONFIGURACIÓN
% -------------------------------------------------------------------------
inputFolder     = 'C:\Users\MSI\Desktop\Tesis\DATOS\Original Data';
colormapMATpath = 'C:\Users\MSI\Desktop\Tesis\Codigo\Codes\python_colormaps.mat';
outputCSV       = 'C:\Users\MSI\Desktop\Tesis\Resultados\descriptores.csv';

% Parámetros del pipeline
sensibilidad = 0.55;
pix_minimos  = 50;
ventana_grad = 50;          % ventana rloess para corrección de rayas
nm_por_pixel = 60000 / 1024;
alpha        = 2000;        % longitud máxima de un SWCNT individual [nm]

% Constantes de conversión de unidades
% Las señales eléctrica y de perfil están en metros (m) tras la conversión
% AmpInvOLS del Asylum Research.
m_a_pm       = 1e12;        % m → pm
nm2_a_um2    = 1e-6;        % nm² → μm²
nm_a_um      = 1e-3;        % nm → μm

% -------------------------------------------------------------------------
% INICIALIZACIÓN
% -------------------------------------------------------------------------
if exist(colormapMATpath,'file')
    S = load(colormapMATpath);
    names = fieldnames(S);
    myColormap = S.(names{1}); %#ok<NASGU>
end

ibwFiles = dir(fullfile(inputFolder,'*.ibw'));

outputDir = fileparts(outputCSV);
if ~exist(outputDir,'dir'), mkdir(outputDir); end
setenv('LC_NUMERIC','C')
fid = fopen(outputCSV,'w');
fprintf(fid, ['imagen,'...
    'voltaje_V,frecuencia_Hz,replica,posicion,'...
    'CNTD,CNTA,CNTS,'...
    'intensidad_media_pm,intensidad_std_pm,intensidad_p90_pm,gradiente_medio_pm_nm,'...
    'elongacion_media,area_media_um2,area_std_um2,tortuosidad_media,'...
    'orient_dominante,coherencia,'...
    'cobertura,indice_percolacion,network_length_um,num_fragmentos,'...
    'perfil_pendiente_pm_nm,perfil_residuo_rms_pm,perfil_rango_pm\n']);

% -------------------------------------------------------------------------
% BUCLE PRINCIPAL
% -------------------------------------------------------------------------
for k = 1:length(ibwFiles)
    try
        filename  = ibwFiles(k).name;
        Full_data = IBWread(fullfile(inputFolder, filename));
        Elec_Raw  = rot90(double(Full_data.y(:,:,5)));
        Topo      = rot90(double(Full_data.y(:,:,1)));

        if ~isequal(size(Elec_Raw), size(Topo))
            Elec_Raw = imresize(Elec_Raw, size(Topo));
        end

        % -----------------------------------------------------------------
        % CORRECCIÓN DE CROSSTALK TOPOGRÁFICO
        % Modelo de regresión lineal múltiple:
        %   E = β0 + β1·T + β2·∂T/∂x + β3·∂T/∂y
        % Se resta la componente topográfica de la señal eléctrica.
        % -----------------------------------------------------------------
        Elec_norm = (Elec_Raw - median(Elec_Raw(:))) / mad(Elec_Raw(:),1);
        Topo_norm = (Topo     - median(Topo(:)))     / mad(Topo(:),1);

        [Gy, Gx] = gradient(Topo_norm);
        X        = [Topo_norm(:), Gx(:), Gy(:), ones(numel(Topo_norm),1)];
        beta     = X \ Elec_norm(:);
        Elec_fit = reshape(X*beta, size(Elec_norm));

        % -----------------------------------------------------------------
        % PIPELINE DE BINARIZACIÓN → BW2
        % Etapas: corrección crosstalk → SyP 5x5 → corrección de fondo
        %         → SyP 5x1 → normalización P1-P99 → binarización integrada
        % -----------------------------------------------------------------
        Elec_corr = Elec_norm - Elec_fit;
        Elec_c1   = Etapa1_SyP_Selectivo(Elec_corr, [5 5], 3);
        Elec_str  = line_strip_correction(Elec_c1);
        Elec_cln  = Etapa1_SyP_Selectivo(Elec_str,  [5 1], 2);
        Eseg      = rescale_1_99(Elec_cln);

        % Binarización global (Otsu multiclase — 6 clases)
        thresh      = multithresh(Eseg, 6);
        BW1         = bwareaopen(Eseg >= thresh(1), pix_minimos);

        % Binarización regional (ventana 51x51)
        T_regional  = adaptthresh(Eseg, sensibilidad, ...
            'NeighborhoodSize',[51 51], ...
            'Statistic','gaussian', ...
            'ForegroundPolarity','bright');
        BW_regional = imbinarize(Eseg, T_regional);

        % Binarización local (ventana 21x21)
        T_local     = adaptthresh(Eseg, sensibilidad, ...
            'NeighborhoodSize',[21 21], ...
            'Statistic','gaussian', ...
            'ForegroundPolarity','bright');
        BW_local    = imbinarize(Eseg, T_local);

        % Máscara integrada: intersección de las tres binarizaciones
        BW2       = bwareaopen(BW1 & BW_regional & BW_local, pix_minimos);
        cobertura = sum(BW2(:)) / numel(BW2);

        % Fallback para imágenes de alta calidad con cobertura baja
        if cobertura < 0.15
            T_fb  = adaptthresh(Eseg, 0.55, ...
                'NeighborhoodSize',[21 21], ...
                'Statistic','gaussian', ...
                'ForegroundPolarity','bright');
            BW2       = bwareaopen(imbinarize(Eseg, T_fb), 50);
            cobertura = sum(BW2(:)) / numel(BW2);
        end

        % Cierre morfológico r=3 (~175 nm) para unir discontinuidades
        % sin destruir la morfología de los segmentos
        BW2_closed = imclose(BW2, strel('disk', 3));

        % -----------------------------------------------------------------
        % PIPELINE ELEC_B — señal para descriptores de intensidad
        % Se deshace la normalización para trabajar en escala original (m).
        % La corrección de rayas usa rloess sobre el perfil vertical,
        % que ajusta polinomios locales ponderados para preservar la
        % tendencia global sin ser arrastrado por saltos abruptos entre
        % filas [Li et al., 2012].
        % -----------------------------------------------------------------
        Elec_corr_B = Elec_Raw - Elec_fit .* mad(Elec_Raw(:),1);
        Elec_syp    = Etapa1_SyP_Selectivo(Elec_corr_B, [5 5], 3);

        perfil_V    = median(Elec_syp, 2);
        tendencia_V = smoothdata(perfil_V, 'rloess', ventana_grad);
        ruido_rayas = perfil_V - tendencia_V;

        [filas, ~] = size(Elec_syp);
        Elec_B = zeros(filas, size(Elec_syp,2));
        for r = 1:filas
            Elec_B(r,:) = Elec_syp(r,:) - ruido_rayas(r);
        end

        % =================================================================
        % GRUPO 1 — DISTRIBUCIÓN ESPACIAL: CNTD, CNTA, CNTS
        % (adimensionales, no requieren conversión de unidades)
        %
        % Se simulan 100 líneas de barrido aleatorias sobre BW2_closed
        % para estimar la distribución de espaciados entre regiones de
        % CNTs y el tamaño de los segmentos, siguiendo la metodología
        % de Castañeda-Uribe y Avila [2020]. La PDF de espaciados y
        % tamaños se modela con una distribución lognormal, y los
        % descriptores se obtienen como áreas bajo esa PDF.
        % =================================================================
        [nrows, ~] = size(BW2_closed);
        espaciados = [];
        tamanios   = [];

        rng(42);
        for ii = 1:100
            fila    = double(BW2_closed(randi(nrows), :));
            cambios = diff([0, fila, 0]);
            ini_cnt = find(cambios ==  1);
            fin_cnt = find(cambios == -1);

            if ~isempty(ini_cnt)
                tamanios = [tamanios, (fin_cnt - ini_cnt) * nm_por_pixel]; %#ok<AGROW>
            end
            if length(ini_cnt) > 1
                for jj = 1:length(ini_cnt)-1
                    esp = (ini_cnt(jj+1) - fin_cnt(jj)) * nm_por_pixel;
                    if esp > 0
                        espaciados = [espaciados, esp]; %#ok<AGROW>
                    end
                end
            end
        end

        % CNTD — área bajo la PDF lognormal en ±20% alrededor del modo η
        esp_pos = espaciados(espaciados > 0);
        if length(esp_pos) > 10
            try
                pd_esp = fitdist(esp_pos(:), 'Lognormal');
                eta    = exp(pd_esp.mu - pd_esp.sigma^2);     % modo (máximo global) de la lognormal
                CNTD   = cdf(pd_esp, 1.2*eta) - cdf(pd_esp, 0.8*eta);
            catch
                CNTD = NaN;
            end
        else
            CNTD = NaN;
        end

        % CNTA — fracción de la PDF lognormal de tamaños por encima de alpha
        tam_pos = tamanios(tamanios > 0);
        if length(tam_pos) > 10
            try
                pd_tam = fitdist(tam_pos(:), 'Lognormal');
                CNTA   = 1 - cdf(pd_tam, alpha);              % = ∫_alpha^∞ PDF_size
                CNTA   = max(0, min(1, CNTA));
            catch
                CNTA = NaN;
            end
        else
            CNTA = NaN;
        end

        % CNTS — cociente CNTA/CNTD: descriptor de apantallamiento (Castañeda)
        if ~isnan(CNTD) && ~isnan(CNTA) && CNTD > 0
            CNTS = CNTA / CNTD;
        else
            CNTS = NaN;
        end

        % =================================================================
        % GRUPO 2 — INTENSIDAD DE GRADIENTE
        % Se trabaja sobre Elec_B (escala original en metros) con máscara
        % BW2 estricta. Conversión final: m → pm (×1e12). Para el gradiente,
        % además se divide por nm_por_pixel para obtener pm/nm físico real.
        % =================================================================
        vals_cnt            = Elec_B(BW2);
        intensidad_media_pm = mean(vals_cnt)       * m_a_pm;        % [m]→[pm]
        intensidad_std_pm   = std(vals_cnt)        * m_a_pm;        % [m]→[pm]
        intensidad_p90_pm   = prctile(vals_cnt,90) * m_a_pm;        % [m]→[pm]

        [Gy_b, Gx_b]          = gradient(Elec_B);                   % [m/px]
        mag_grad              = sqrt(Gx_b.^2 + Gy_b.^2);
        gradiente_medio_mpx   = mean(mag_grad(BW2));                % [m/px]
        gradiente_medio_pm_nm = gradiente_medio_mpx * m_a_pm / nm_por_pixel;  % [pm/nm]

        % =================================================================
        % GRUPO 3 — FORMA Y MORFOLOGÍA
        % regionprops sobre BW2_closed (r=3).
        % El esqueleto (bwskel + spur 5px) se calcula aquí y se reutiliza
        % en Orientación, tortuosidad y Longitud de Red.
        % Conversión final: áreas nm² → μm² (×1e-6).
        % =================================================================
        props = regionprops(BW2_closed,'Area','MajorAxisLength','MinorAxisLength');

        if isempty(props)
            elongacion_media = NaN;
            tortuosidad_media  = NaN;
            area_media_um2   = NaN;
            area_std_um2     = NaN;
            BW_skel          = false(size(BW2_closed));
        else
            mayor = [props.MajorAxisLength];
            menor = [props.MinorAxisLength];
            menor(menor == 0) = 1;
            elongacion_media = mean(mayor ./ menor);

            areas_nm2      = [props.Area] * nm_por_pixel^2;         % [nm²]
            area_media_um2 = mean(areas_nm2) * nm2_a_um2;           % [nm²]→[μm²]
            area_std_um2   = std(areas_nm2)  * nm2_a_um2;           % [nm²]→[μm²]

            % Esqueleto compartido: bwskel + eliminación de ramas < 5px
            BW_skel = bwmorph(bwskel(BW2_closed), 'spur', 5);

            % tortuosidad: camino más largo (diámetro geodésico) por
            % componente del esqueleto, sin fragmentar en las uniones. Por
            % cada componente se toma el par de extremos más alejados
            % geodésicamente (doble barrido); el arco usa distancia geodésica
            % (diagonales = sqrt(2)) y la cuerda es la distancia euclidiana
            % entre esos extremos.
            Lmin_arco   = 15;     % arco mínimo para contar un camino [px]
            CC_skel     = bwconncomp(BW_skel, 8);
            tortuosidad = [];
            for ii = 1:CC_skel.NumObjects
                pixels = CC_skel.PixelIdxList{ii};
                if numel(pixels) < 8, continue; end
                skel_comp         = false(size(BW_skel));
                skel_comp(pixels) = true;
                [ye, xe]          = find(bwmorph(skel_comp, 'endpoints'));
                if numel(ye) < 2, continue; end
                lin = sub2ind(size(skel_comp), ye, xe);
                D1  = bwdistgeodesic(skel_comp, xe(1), ye(1), 'quasi-euclidean');
                [~, a]         = max(D1(lin));                  % extremo A más lejano
                DA  = bwdistgeodesic(skel_comp, xe(a), ye(a), 'quasi-euclidean');
                [long_arco, b] = max(DA(lin));                 % B = diámetro desde A
                dist_ext = hypot(ye(a)-ye(b), xe(a)-xe(b));
                if isfinite(long_arco) && long_arco >= Lmin_arco && dist_ext > 0
                    tortuosidad(end+1) = long_arco / dist_ext; %#ok<AGROW>
                end
            end
            if isempty(tortuosidad)
                tortuosidad_media = NaN;
            else
                tortuosidad_media = mean(tortuosidad);
            end
        end

        % =========================================================
        % ORIENTACIÓN DOMINANTE Y COHERENCIA
        % Tensor de estructura sobre la máscara suavizada (escala de grises),
        % con derivadas gaussianas. Evita el sesgo de grilla del esqueleto binario.
        % =========================================================
         sigma_d = 2;    % escala de derivada (px) ~117 nm a 58.6 nm/px
         sigma_i = 8;    % escala de integración (px) ~469 nm
         G_ori = imgaussfilt(double(BW2_closed), sigma_d);
         [Gx_o, Gy_o] = gradient(G_ori);    % BIEN: MATLAB devuelve [FX, FY] = [d/dx, d/dy]         
         Jxx_m = imgaussfilt(Gx_o.^2,     sigma_i);
         Jyy_m = imgaussfilt(Gy_o.^2,     sigma_i);
         Jxy_m = imgaussfilt(Gx_o.*Gy_o,  sigma_i);
         roi = BW2_closed;                       % acumular sobre la red segmentada
         Sxx = sum(Jxx_m(roi)); Syy = sum(Jyy_m(roi)); Sxy = sum(Jxy_m(roi));
        if sum(roi(:)) > 10 && (Sxx + Syy) > 0
            orient_dominante = 0.5 * atan2d(2*Sxy, Sxx - Syy);   % dir. del gradiente dominante
            orient_dominante = mod(orient_dominante + 90, 180);  % +90 -> dir. de la estructura; [0,180)
            lambda1 = 0.5*(Sxx+Syy) + 0.5*sqrt((Sxx-Syy)^2 + 4*Sxy^2);
            lambda2 = 0.5*(Sxx+Syy) - 0.5*sqrt((Sxx-Syy)^2 + 4*Sxy^2);
            coherencia = (lambda1 - lambda2) / (lambda1 + lambda2);
        else
            orient_dominante = NaN;
            coherencia = NaN;
        end

        % =================================================================
        % GRUPO 5 — CONECTIVIDAD Y TOPOLOGÍA
        % bwconncomp sobre BW2_closed (r=3).
        % indice_percolacion: fracción del área total en el clúster mayor.
        % num_fragmentos: cantidad de regiones desconectadas.
        % network_length: longitud física total del esqueleto, medida con
        % diagonales = sqrt(2) (no conteo de píxeles).
        % Conversión final: nm → μm (÷1000).
        % =================================================================
        CC_perc       = bwconncomp(BW2_closed);
        num_fragmentos = CC_perc.NumObjects;

        if num_fragmentos == 0
            indice_percolacion = 0;
        else
            sizes              = cellfun(@numel, CC_perc.PixelIdxList);
            indice_percolacion = max(sizes) / sum(sizes);
        end

        % Longitud real del esqueleto: adyacencias ortogonales (peso 1) y
        % diagonales genuinas (peso sqrt(2)); se excluyen las diagonales de
        % esquina para no sobrecontar.
        H_adj = BW_skel(:,1:end-1) & BW_skel(:,2:end);
        V_adj = BW_skel(1:end-1,:) & BW_skel(2:end,:);
        n_orto = nnz(H_adj) + nnz(V_adj);
        D1_adj = BW_skel(1:end-1,1:end-1) & BW_skel(2:end,2:end) & ...
                 ~BW_skel(1:end-1,2:end)  & ~BW_skel(2:end,1:end-1);
        D2_adj = BW_skel(1:end-1,2:end)   & BW_skel(2:end,1:end-1) & ...
                 ~BW_skel(1:end-1,1:end-1) & ~BW_skel(2:end,2:end);
        n_diag = nnz(D1_adj) + nnz(D2_adj);
        network_length_nm = (n_orto + sqrt(2)*n_diag) * nm_por_pixel;  % [nm]
        network_length_um = network_length_nm * nm_a_um;              % [nm]→[μm]

        % =================================================================
        % GRUPO 6 — PERFIL DE GRADIENTE
        % Perfil vertical (mediana por fila) de Elec_B sobre imagen completa.
        % Conversión: m → pm (×1e12). Para la pendiente, además se divide
        % por nm_por_pixel para obtener pm/nm físico real.
        % =================================================================
        perfil_B         = median(Elec_B, 2);                       % [m]
        x_fila           = (1:length(perfil_B))';
        p_fit            = polyfit(x_fila, perfil_B, 1);            % p_fit(1) en [m/px]
        perfil_fit_B     = polyval(p_fit, x_fila);
        residuos         = perfil_B - perfil_fit_B;                 % [m]

        perfil_pendiente_pm_nm = p_fit(1)              * m_a_pm / nm_por_pixel;  % [pm/nm]
        perfil_residuo_rms_pm  = sqrt(mean(residuos.^2)) * m_a_pm;               % [pm]
        perfil_rango_pm        = (max(perfil_B) - min(perfil_B)) * m_a_pm;       % [pm]

        % =================================================================
        % CARACTERÍSTICAS DE FABRICACIÓN
        % =================================================================
        [voltaje_V, frecuencia_Hz, replica, posicion] = parsear_fabricacion(filename);

        % =================================================================
        % ESCRITURA EN CSV
        % =================================================================
        fprintf(fid, ['%s,'...
            '%g,%g,%d,%d,'...
            '%.6e,%.6e,%.6e,'...
            '%.6e,%.6e,%.6e,%.6e,'...
            '%.6e,%.6e,%.6e,%.6e,'...
            '%.6e,%.6e,'...
            '%.6e,%.6e,%.6e,%d,'...
            '%.6e,%.6e,%.6e\n'], ...
            filename, ...
            voltaje_V, frecuencia_Hz, replica, posicion, ...
            CNTD, CNTA, CNTS, ...
            intensidad_media_pm, intensidad_std_pm, intensidad_p90_pm, gradiente_medio_pm_nm, ...
            elongacion_media, area_media_um2, area_std_um2, tortuosidad_media, ...
            orient_dominante, coherencia, ...
            cobertura, indice_percolacion, network_length_um, num_fragmentos, ...
            perfil_pendiente_pm_nm, perfil_residuo_rms_pm, perfil_rango_pm);

        fprintf('Procesado %d/%d: %s\n', k, length(ibwFiles), filename);

    catch ME
        fprintf('Error en %s: %s\n', filename, ME.message);
    end
end

fclose(fid);
fprintf('Descriptores exportados → %s\n', outputCSV);
end


% =========================================================================
% FUNCIONES AUXILIARES
% =========================================================================

function [voltaje_V, frecuencia_Hz, replica, posicion] = parsear_fabricacion(filename)
% Parsea las características de fabricación desde el nombre de archivo.
% Formato esperado: [0-2][a-c]-[1-9].ibw
%   0→5V,  1→10V,  2→15V
%   a→10Hz, b→1000Hz, c→100000Hz
%   Imagen 1-9: replica=ceil(n/3), posicion=mod(n-1,3)+1

    voltaje_V     = NaN;
    frecuencia_Hz = NaN;
    replica       = NaN;
    posicion      = NaN;

    [~, nombre, ~] = fileparts(filename);

    tok = regexp(nombre, '^([0-2])([abc])-([1-9])$', 'tokens');

    if isempty(tok)
        warning('Nombre de archivo no coincide con el formato esperado: %s', filename);
        return;
    end

    num_char   = tok{1}{1};
    letra_char = tok{1}{2};
    img_char   = tok{1}{3};

    switch num_char
        case '0', voltaje_V = 5;
        case '1', voltaje_V = 10;
        case '2', voltaje_V = 15;
    end

    switch letra_char
        case 'a', frecuencia_Hz = 10;
        case 'b', frecuencia_Hz = 1000;
        case 'c', frecuencia_Hz = 100000;
    end

    img_num  = str2double(img_char);
    replica  = ceil(img_num / 3);
    posicion = mod(img_num - 1, 3) + 1;
end

function I_out = line_strip_correction(I_in)
% Corrección de artefactos de barrido horizontal.
% Estima el fondo de cada fila usando un percentil adaptativo
% basado en la variabilidad relativa de intensidad (ρ = MAD/rango).
% Filas homogéneas usan percentil alto (~45%); filas con CNTs
% usan percentil bajo (~25%) para no contaminar el fondo.

    [r, ~]  = size(I_in);
    I_out   = zeros(size(I_in));
    for i = 1:r
        row    = I_in(i,:);
        sigma  = mad(row, 1);
        dyn    = prctile(row,95) - prctile(row,5);
        ratio  = sigma / dyn;
        p      = max(25, min(45, 40 - 20*ratio));
        cutoff = prctile(row, p);
        bg_pix = row(row <= cutoff);
        if isempty(bg_pix)
            offset = median(row);
        else
            offset = median(bg_pix);
        end
        I_out(i,:) = row - offset;
    end
end

function I_Out = Etapa1_SyP_Selectivo(I_In, kernel_size, n_sigmas)
% Eliminación de ruido impulsivo (sal y pimienta) mediante filtro de mediana.
% Los píxeles cuyo residuo respecto al filtro supera n_sigmas·σ_MAD
% son reemplazados por el valor del filtro de mediana.

    Fondo_Ref     = medfilt2(I_In, kernel_size);
    Residuo       = abs(I_In - Fondo_Ref);
    sigma_ruido   = median(Residuo(:)) / 0.6745;
    Mascara_Malos = Residuo > (n_sigmas * sigma_ruido);
    I_Out         = I_In;
    I_Out(Mascara_Malos) = Fondo_Ref(Mascara_Malos);
end

function Img_Vis = rescale_1_99(Data)
% Normalización robusta entre percentil 1 y 99.

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
