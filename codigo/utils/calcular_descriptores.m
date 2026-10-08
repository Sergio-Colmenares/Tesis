function [D, G] = calcular_descriptores(E, P)
% CALCULAR_DESCRIPTORES  Los 20 descriptores de una imagen, con las mismas
% fórmulas, máscaras y unidades que pipeline/Descriptores_Final.m.
%
%   [D, G] = calcular_descriptores(E)       E = pipeline_etapas(ruta)
%   [D, G] = calcular_descriptores(E, P)
%
%   D  estructura con los 20 descriptores; los nombres de campo son los
%      mismos que las columnas de resultados/descriptores.csv.
%   G  elementos intermedios para graficar (líneas de barrido, tramos,
%      ajustes lognormales, elipses, cuerdas de tortuosidad, orientación
%      por componente, clúster mayor, perfil y su ajuste).

    if nargin < 2, P = parametros_pipeline(); end
    nm  = P.nm_px;
    Me  = E.Me;
    Mmor = E.Mmor;
    EB  = E.EB;

    % =================================================================
    % GRUPO 1 — DISTRIBUCIÓN ESPACIAL (sobre M_mor, 100 líneas, rng(42))
    % =================================================================
    [nrows, ~] = size(Mmor);
    espaciados = [];
    tamanios   = [];
    G.lineas   = zeros(100, 1);
    G.tramos   = zeros(0, 3);          % [fila, columna inicio, columna fin]
    rng(42);
    for ii = 1:100
        r       = randi(nrows);
        G.lineas(ii) = r;
        fila    = double(Mmor(r, :));
        cambios = diff([0, fila, 0]);
        ini_cnt = find(cambios ==  1);
        fin_cnt = find(cambios == -1);
        if ~isempty(ini_cnt)
            tamanios = [tamanios, (fin_cnt - ini_cnt) * nm]; %#ok<AGROW>
            G.tramos = [G.tramos; repmat(r, numel(ini_cnt), 1), ini_cnt(:), fin_cnt(:) - 1]; %#ok<AGROW>
        end
        if length(ini_cnt) > 1
            for jj = 1:length(ini_cnt) - 1
                esp = (ini_cnt(jj + 1) - fin_cnt(jj)) * nm;
                if esp > 0
                    espaciados = [espaciados, esp]; %#ok<AGROW>
                end
            end
        end
    end
    G.espaciados = espaciados;
    G.tamanios   = tamanios;
    G.pd_esp = []; G.pd_tam = []; G.eta = NaN;

    D.CNTD = NaN;
    esp_pos = espaciados(espaciados > 0);
    if length(esp_pos) > 10
        try
            pd_esp = fitdist(esp_pos(:), 'Lognormal');
            eta    = exp(pd_esp.mu - pd_esp.sigma^2);
            D.CNTD = cdf(pd_esp, 1.2 * eta) - cdf(pd_esp, 0.8 * eta);
            G.pd_esp = pd_esp; G.eta = eta;
        catch
        end
    end

    D.CNTA = NaN;
    tam_pos = tamanios(tamanios > 0);
    if length(tam_pos) > 10
        try
            pd_tam = fitdist(tam_pos(:), 'Lognormal');
            D.CNTA = max(0, min(1, 1 - cdf(pd_tam, P.alpha)));
            G.pd_tam = pd_tam;
        catch
        end
    end

    if ~isnan(D.CNTD) && ~isnan(D.CNTA) && D.CNTD > 0
        D.CNTS = D.CNTA / D.CNTD;
    else
        D.CNTS = NaN;
    end

    % =================================================================
    % GRUPO 2 — INTENSIDAD (E_B sobre M_e, m -> pm)
    % =================================================================
    vals = EB(Me);
    D.intensidad_media_pm = mean(vals) * 1e12;
    D.intensidad_std_pm   = std(vals) * 1e12;
    D.intensidad_p90_pm   = prctile(vals, 90) * 1e12;
    [Gy_b, Gx_b] = gradient(EB);
    G.mag_grad   = sqrt(Gx_b.^2 + Gy_b.^2) * 1e12 / nm;     % [pm/nm]
    D.gradiente_medio_pm_nm = mean(G.mag_grad(Me));

    % =================================================================
    % GRUPO 3 — FORMA (regionprops sobre M_mor) Y TORTUOSIDAD (esqueleto)
    % =================================================================
    props = regionprops(Mmor, 'Area', 'MajorAxisLength', 'MinorAxisLength', ...
        'Centroid', 'Orientation');
    G.props  = props;
    G.cuerdas = zeros(0, 4);           % [xA yA xB yB] de cada componente retenida
    if isempty(props)
        D.elongacion_media  = NaN;
        D.area_media_um2    = NaN;
        D.area_std_um2      = NaN;
        D.tortuosidad_media = NaN;
        BW_skel = false(size(Mmor));
    else
        mayor = [props.MajorAxisLength];
        menor = [props.MinorAxisLength];
        menor(menor == 0) = 1;
        D.elongacion_media = mean(mayor ./ menor);
        areas_nm2 = [props.Area] * nm^2;
        D.area_media_um2 = mean(areas_nm2) * 1e-6;
        D.area_std_um2   = std(areas_nm2) * 1e-6;

        BW_skel = bwmorph(bwskel(Mmor), 'spur', P.spur);
        Lmin_arco   = 15;
        CC_skel     = bwconncomp(BW_skel, 8);
        tortuosidad = [];
        for ii = 1:CC_skel.NumObjects
            pixels = CC_skel.PixelIdxList{ii};
            if numel(pixels) < 8, continue; end
            skel_comp = false(size(BW_skel));
            skel_comp(pixels) = true;
            [ye, xe] = find(bwmorph(skel_comp, 'endpoints'));
            if numel(ye) < 2, continue; end
            lin = sub2ind(size(skel_comp), ye, xe);
            D1  = bwdistgeodesic(skel_comp, xe(1), ye(1), 'quasi-euclidean');
            [~, a] = max(D1(lin));
            DA  = bwdistgeodesic(skel_comp, xe(a), ye(a), 'quasi-euclidean');
            [long_arco, b] = max(DA(lin));
            dist_ext = hypot(ye(a) - ye(b), xe(a) - xe(b));
            if isfinite(long_arco) && long_arco >= Lmin_arco && dist_ext > 0
                tortuosidad(end + 1) = long_arco / dist_ext; %#ok<AGROW>
                G.cuerdas(end + 1, :) = [xe(a), ye(a), xe(b), ye(b)]; %#ok<AGROW>
            end
        end
        if isempty(tortuosidad)
            D.tortuosidad_media = NaN;
        else
            D.tortuosidad_media = mean(tortuosidad);
        end
    end
    G.skel = BW_skel;

    % =================================================================
    % GRUPO 4 — ORIENTACIÓN (tensor de estructura sobre M_mor)
    % =================================================================
    sigma_d = 2; sigma_i = 8;
    G_ori = imgaussfilt(double(Mmor), sigma_d);
    [Gx_o, Gy_o] = gradient(G_ori);
    Jxx_m = imgaussfilt(Gx_o.^2,    sigma_i);
    Jyy_m = imgaussfilt(Gy_o.^2,    sigma_i);
    Jxy_m = imgaussfilt(Gx_o.*Gy_o, sigma_i);
    roi = Mmor;
    Sxx = sum(Jxx_m(roi)); Syy = sum(Jyy_m(roi)); Sxy = sum(Jxy_m(roi));
    if sum(roi(:)) > 10 && (Sxx + Syy) > 0
        D.orient_dominante = mod(0.5 * atan2d(2 * Sxy, Sxx - Syy) + 90, 180);
        l1 = 0.5 * (Sxx + Syy) + 0.5 * sqrt((Sxx - Syy)^2 + 4 * Sxy^2);
        l2 = 0.5 * (Sxx + Syy) - 0.5 * sqrt((Sxx - Syy)^2 + 4 * Sxy^2);
        D.coherencia = (l1 - l2) / (l1 + l2);
    else
        D.orient_dominante = NaN;
        D.coherencia = NaN;
    end
    G.G_ori = G_ori;

    % Orientación local por componente (solo para visualizar, como en mosaicos_2b)
    st = regionprops(bwlabel(Mmor), 'Area', 'Centroid', 'PixelIdxList', 'MajorAxisLength');
    G.seg = zeros(0, 4);               % [x, y, ángulo, longitud]
    for kk = 1:numel(st)
        if st(kk).Area < 150, continue; end
        ix = st(kk).PixelIdxList;
        sx = sum(Jxx_m(ix)); sy = sum(Jyy_m(ix)); sxy = sum(Jxy_m(ix));
        if (sx + sy) <= 0, continue; end
        G.seg(end + 1, :) = [st(kk).Centroid, ...
            mod(0.5 * atan2d(2 * sxy, sx - sy) + 90, 180), st(kk).MajorAxisLength]; %#ok<AGROW>
    end

    % =================================================================
    % GRUPO 5 — CONECTIVIDAD Y TOPOLOGÍA
    % =================================================================
    D.cobertura = nnz(Me) / numel(Me);
    CC = bwconncomp(Mmor);
    D.num_fragmentos = CC.NumObjects;
    G.mayor = false(size(Mmor));
    if D.num_fragmentos == 0
        D.indice_percolacion = 0;
    else
        sizes = cellfun(@numel, CC.PixelIdxList);
        D.indice_percolacion = max(sizes) / sum(sizes);
        [~, im] = max(sizes);
        G.mayor(CC.PixelIdxList{im}) = true;
    end
    H_adj  = BW_skel(:, 1:end-1) & BW_skel(:, 2:end);
    V_adj  = BW_skel(1:end-1, :) & BW_skel(2:end, :);
    D1_adj = BW_skel(1:end-1, 1:end-1) & BW_skel(2:end, 2:end) & ...
             ~BW_skel(1:end-1, 2:end)  & ~BW_skel(2:end, 1:end-1);
    D2_adj = BW_skel(1:end-1, 2:end)   & BW_skel(2:end, 1:end-1) & ...
             ~BW_skel(1:end-1, 1:end-1) & ~BW_skel(2:end, 2:end);
    n_orto = nnz(H_adj) + nnz(V_adj);
    n_diag = nnz(D1_adj) + nnz(D2_adj);
    D.network_length_um = (n_orto + sqrt(2) * n_diag) * nm * 1e-3;

    % =================================================================
    % GRUPO 6 — PERFIL DE GRADIENTE (E_B completa)
    % =================================================================
    perfil_B = median(EB, 2);
    x_fila   = (1:length(perfil_B))';
    p_fit    = polyfit(x_fila, perfil_B, 1);
    ajuste   = polyval(p_fit, x_fila);
    residuos = perfil_B - ajuste;
    D.perfil_pendiente_pm_nm = p_fit(1) * 1e12 / nm;
    D.perfil_residuo_rms_pm  = sqrt(mean(residuos.^2)) * 1e12;
    D.perfil_rango_pm        = (max(perfil_B) - min(perfil_B)) * 1e12;
    G.perfil = perfil_B;
    G.ajuste = ajuste;

    D = orderfields(D, {'CNTD', 'CNTA', 'CNTS', ...
        'intensidad_media_pm', 'intensidad_std_pm', 'intensidad_p90_pm', 'gradiente_medio_pm_nm', ...
        'elongacion_media', 'area_media_um2', 'area_std_um2', 'tortuosidad_media', ...
        'orient_dominante', 'coherencia', ...
        'cobertura', 'indice_percolacion', 'network_length_um', 'num_fragmentos', ...
        'perfil_pendiente_pm_nm', 'perfil_residuo_rms_pm', 'perfil_rango_pm'});
end
