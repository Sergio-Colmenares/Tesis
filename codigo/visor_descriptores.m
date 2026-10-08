function visor_descriptores(k0)
% VISOR_DESCRIPTORES  Visor interactivo de los 20 descriptores, imagen por imagen.
%
%   visor_descriptores            abre la primera imagen de datos/crudos
%   visor_descriptores(k)         abre la imagen número k (orden alfabético)
%   visor_descriptores('2b-5')    abre la imagen con ese nombre
%
% Muestra cómo se mide cada grupo de descriptores sobre la imagen y la
% tabla con los 20 valores. Si existe resultados/descriptores.csv, compara
% cada valor con el del CSV (columna "CSV"): así se comprueba que el visor
% y pipeline/Descriptores_Final.m calculan lo mismo.
%
% Paneles:
%   1  Distribución espacial: líneas de barrido y tramos de CNT sobre M_mor
%   2  PDF de espaciados + ajuste lognormal + banda eta ± 20 %   (CNTD)
%   3  PDF de longitudes de tramo + ajuste lognormal + alfa      (CNTA)
%   4  E_B sobre M_e                                             (intensidad)
%   5  Histograma de E_B en M_e: media y P90
%   6  |grad E_B| sobre M_e                                      (gradiente medio)
%   7  Componentes de M_mor con sus elipses                      (elongación, área)
%   8  Esqueleto y cuerda de cada componente                     (tortuosidad)
%   9  Máscara suavizada, orientación por componente y global    (orientación)
%  10  Clúster mayor y esqueleto                                 (conectividad)
%  11  Perfil vertical de E_B y ajuste lineal                    (perfil)
%  12  Tabla de los 20 descriptores
%
% Navegación: flechas izquierda/derecha (o botones); clic en un panel lo
% abre en grande; zoom sincronizado entre los paneles de imagen.

    rutas = rutas_tesis();
    archivos = dir(fullfile(rutas.crudos, '*.ibw'));
    if isempty(archivos)
        error('No hay archivos .ibw en %s', rutas.crudos);
    end
    nombres = {archivos.name};

    cmap = parula(256);
    if exist(rutas.colormap, 'file')
        S = load(rutas.colormap);
        campos = fieldnames(S);
        cmap = S.(campos{1});
    end

    T_csv = [];
    csv = fullfile(rutas.resultados, 'descriptores.csv');
    if exist(csv, 'file')
        T_csv = readtable(csv, 'TextType', 'char');
    end

    k = 1;
    if nargin >= 1
        if ischar(k0) || isstring(k0)
            k = find(startsWith(nombres, char(k0)), 1);
            if isempty(k)
                error('No se encontró la imagen %s en %s', char(k0), rutas.crudos);
            end
        else
            k = max(1, min(numel(nombres), round(k0)));
        end
    end

    P = parametros_pipeline();

    fig = figure('Name', 'Visor de descriptores', 'Color', 'w', ...
        'Units', 'normalized', 'Position', [0.02 0.05 0.96 0.86], ...
        'NumberTitle', 'off', 'KeyPressFcn', @tecla);
    uicontrol(fig, 'Style', 'pushbutton', 'String', '<< Anterior', ...
        'Units', 'normalized', 'Position', [0.005 0.955 0.06 0.035], ...
        'Callback', @(~, ~) mover(-1), 'KeyPressFcn', @tecla);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Siguiente >>', ...
        'Units', 'normalized', 'Position', [0.07 0.955 0.06 0.035], ...
        'Callback', @(~, ~) mover(+1), 'KeyPressFcn', @tecla);
    info = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.14 0.952 0.85 0.038], 'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left', 'FontSize', 10, 'FontWeight', 'bold');

    dibujar();

    % ------------------------------------------------------------------
    function mover(d)
        k = mod(k - 1 + d, numel(nombres)) + 1;
        dibujar();
    end

    function tecla(~, ev)
        switch ev.Key
            case {'rightarrow', 'space'}
                mover(+1);
            case 'leftarrow'
                mover(-1);
        end
    end

    function dibujar()
        set(fig, 'Pointer', 'watch');
        set(info, 'String', sprintf('Procesando %s ...', nombres{k}));
        drawnow;

        E = pipeline_etapas(fullfile(rutas.crudos, nombres{k}), P);
        [D, G] = calcular_descriptores(E, P);
        ref = fila_csv(T_csv, nombres{k});
        delete(findall(fig, 'Type', 'axes'));

        [vV, fHz, rep, pos] = parsear_fabricacion_ibw(nombres{k});
        txt_resp = '';
        if E.respaldo, txt_resp = '   |   RESPALDO ACTIVADO (M_e = M_L)'; end
        set(info, 'String', sprintf('[%d/%d]  %s   |   %g V, %g Hz, réplica %d, posición %d%s', ...
            k, numel(nombres), nombres{k}, vV, fHz, rep, pos, txt_resp));

        paneles = {
            @(ax) p_lineas(ax, E, G)
            @(ax) p_pdf(ax, G.espaciados, G.pd_esp, 'esp', G.eta, D.CNTD, P)
            @(ax) p_pdf(ax, G.tamanios, G.pd_tam, 'tam', G.eta, D.CNTA, P)
            @(ax) p_mapa(ax, E.EB * 1e12, E.Me, cmap, ...
                sprintf('E_B en M_e: media %.0f pm, P90 %.0f pm', ...
                D.intensidad_media_pm, D.intensidad_p90_pm))
            @(ax) p_hist_int(ax, E.EB(E.Me) * 1e12, D)
            @(ax) p_mapa(ax, G.mag_grad, E.Me, cmap, ...
                sprintf('|\\nabla E_B| en M_e: media %.3f pm/nm', D.gradiente_medio_pm_nm))
            @(ax) p_forma(ax, E, G, D)
            @(ax) p_tortuosidad(ax, E, G, D)
            @(ax) p_orientacion(ax, G, D)
            @(ax) p_conectividad(ax, E, G, D)
            @(ax) p_perfil(ax, G, D)
            @(ax) p_tabla(ax, D, ref)
            };
        de_imagen = [1 4 6 7 8 9 10];

        ejes = gobjects(numel(paneles), 1);
        for i = 1:numel(paneles)
            ax = subplot(3, 4, i, 'Parent', fig);
            paneles{i}(ax);
            f_ampliar = @(~, ~) ampliar(paneles{i}, nombres{k});
            set(ax, 'ButtonDownFcn', f_ampliar);
            set(findall(ax, '-not', 'Type', 'axes'), 'ButtonDownFcn', f_ampliar);
            ejes(i) = ax;
        end
        linkaxes(ejes(de_imagen), 'xy');
        set(fig, 'Pointer', 'arrow');
    end
end


% =========================================================================
% PANELES
% =========================================================================
function p_lineas(ax, E, G)
    fondo_gris(ax, E.Mmor);
    hold(ax, 'on');
    N = size(E.Mmor, 2);
    L = G.lineas(:)';
    plot(ax, reshape([ones(size(L)); N * ones(size(L)); nan(size(L))], 1, []), ...
         reshape([L; L; nan(size(L))], 1, []), '-', 'Color', [1 0.85 0], 'LineWidth', 0.3);
    t = G.tramos;
    if ~isempty(t)
        plot(ax, reshape([t(:, 2)'; t(:, 3)'; nan(1, size(t, 1))], 1, []), ...
             reshape([t(:, 1)'; t(:, 1)'; nan(1, size(t, 1))], 1, []), ...
             'g-', 'LineWidth', 1.2);
    end
    hold(ax, 'off');
    title(ax, 'Distribución espacial: 100 líneas, tramos CNT (verde)', 'FontSize', 9);
end

function p_pdf(ax, datos_nm, pd, tipo, eta, valor, P)
    if isempty(datos_nm)
        axis(ax, 'off'); title(ax, 'Sin datos', 'FontSize', 9); return;
    end
    x_um = datos_nm / 1000;
    histogram(ax, x_um, 40, 'Normalization', 'pdf', ...
        'FaceColor', [0.75 0.75 0.75], 'EdgeColor', 'none');
    hold(ax, 'on');
    if ~isempty(pd)
        xs = linspace(0, prctile(x_um, 99), 400);
        plot(ax, xs, pdf(pd, xs * 1000) * 1000, 'b-', 'LineWidth', 1.5);
    end
    yl = ylim(ax);
    if strcmp(tipo, 'esp')
        if ~isnan(eta)
            a = 0.8 * eta / 1000; b = 1.2 * eta / 1000;
            patch(ax, [a b b a], [0 0 yl(2) yl(2)], [0.2 0.7 0.2], ...
                'FaceAlpha', 0.25, 'EdgeColor', 'none');
            plot(ax, [eta eta] / 1000, yl, 'g-', 'LineWidth', 1.2);
        end
        xlabel(ax, 'espaciado entre tramos de CNT [\mum]');
        title(ax, sprintf('CNTD = %.4f  (área en \\eta \\pm 20 %%)', valor), 'FontSize', 9);
    else
        al = P.alpha / 1000;
        xr = xlim(ax);
        if xr(2) > al
            patch(ax, [al xr(2) xr(2) al], [0 0 yl(2) yl(2)], [0.9 0.3 0.2], ...
                'FaceAlpha', 0.2, 'EdgeColor', 'none');
        end
        plot(ax, [al al], yl, 'r-', 'LineWidth', 1.2);
        xlabel(ax, 'longitud de tramo de CNT [\mum]');
        title(ax, sprintf('CNTA = %.4f  (área sobre \\alpha = %g \\mum)', valor, al), 'FontSize', 9);
    end
    ylim(ax, yl);
    hold(ax, 'off');
    ylabel(ax, 'densidad');
    set(ax, 'FontSize', 8);
end

function p_mapa(ax, A, mascara, cmap, titulo)
    imagesc(ax, A, 'AlphaData', double(mascara));
    set(ax, 'Color', 'k');
    colormap(ax, cmap);
    v = A(mascara);
    if ~isempty(v)
        L = prctile(v, [1 99]);
        if L(2) > L(1), set(ax, 'CLim', L); end
    end
    axis(ax, 'image'); set(ax, 'XTick', [], 'YTick', []);
    title(ax, titulo, 'FontSize', 9);
end

function p_hist_int(ax, v, D)
    histogram(ax, v, 60, 'FaceColor', [0.4 0.55 0.85], 'EdgeColor', 'none');
    hold(ax, 'on');
    yl = ylim(ax);
    plot(ax, [1 1] * D.intensidad_media_pm, yl, 'k-', 'LineWidth', 1.5);
    plot(ax, [1 1] * D.intensidad_p90_pm, yl, 'r--', 'LineWidth', 1.5);
    hold(ax, 'off');
    legend(ax, {'E_B en M_e', 'media', 'P90'}, 'FontSize', 7, 'Location', 'best');
    xlabel(ax, 'E_B [pm]'); ylabel(ax, 'píxeles'); set(ax, 'FontSize', 8);
    title(ax, sprintf('Intensidad: desv. est. %.1f pm', D.intensidad_std_pm), 'FontSize', 9);
end

function p_forma(ax, E, G, D)
    etiquetas = bwlabel(E.Mmor);
    image(ax, label2rgb(etiquetas, 'jet', 'k', 'shuffle'));
    axis(ax, 'image'); set(ax, 'XTick', [], 'YTick', []);
    hold(ax, 'on');
    s = G.props;
    if ~isempty(s)
        [~, orden] = sort([s.Area], 'descend');
        phi = linspace(0, 2 * pi, 60);
        for j = orden(1:min(25, numel(orden)))
            a = s(j).MajorAxisLength / 2;
            b = s(j).MinorAxisLength / 2;
            th = pi * s(j).Orientation / 180;
            R = [cos(th) sin(th); -sin(th) cos(th)];
            xy = R * [a * cos(phi); b * sin(phi)];
            plot(ax, xy(1, :) + s(j).Centroid(1), xy(2, :) + s(j).Centroid(2), ...
                'w-', 'LineWidth', 1);
        end
    end
    hold(ax, 'off');
    title(ax, sprintf('Elong. %.2f | área %.2f \\pm %.2f \\mum^2 | N_c = %d', ...
        D.elongacion_media, D.area_media_um2, D.area_std_um2, D.num_fragmentos), 'FontSize', 9);
end

function p_tortuosidad(ax, E, G, D)
    base = 0.3 * double(E.Mmor);
    r = base; g = base; b = base;
    r(G.skel) = 1; g(G.skel) = 1; b(G.skel) = 1;
    image(ax, cat(3, r, g, b));
    axis(ax, 'image'); set(ax, 'XTick', [], 'YTick', []);
    hold(ax, 'on');
    c = G.cuerdas;
    if ~isempty(c)
        n = size(c, 1);
        plot(ax, reshape([c(:, 1)'; c(:, 3)'; nan(1, n)], 1, []), ...
             reshape([c(:, 2)'; c(:, 4)'; nan(1, n)], 1, []), 'c-', 'LineWidth', 1);
        plot(ax, [c(:, 1); c(:, 3)], [c(:, 2); c(:, 4)], 'm.', 'MarkerSize', 8);
    end
    hold(ax, 'off');
    title(ax, sprintf('Tortuosidad media %.3f (%d componentes, cuerda en cian)', ...
        D.tortuosidad_media, size(c, 1)), 'FontSize', 9);
end

function p_orientacion(ax, G, D)
    imagesc(ax, G.G_ori); colormap(ax, gray(256));
    axis(ax, 'image'); set(ax, 'XTick', [], 'YTick', []);
    hold(ax, 'on');
    s = G.seg;
    if ~isempty(s)
        n = size(s, 1);
        dx = 0.4 * s(:, 4) .* cosd(s(:, 3));
        dy = 0.4 * s(:, 4) .* sind(s(:, 3));
        plot(ax, reshape([s(:, 1)' - dx'; s(:, 1)' + dx'; nan(1, n)], 1, []), ...
             reshape([s(:, 2)' - dy'; s(:, 2)' + dy'; nan(1, n)], 1, []), ...
             '-', 'Color', [1 0.85 0], 'LineWidth', 1.5);
    end
    if ~isnan(D.orient_dominante)
        N = size(G.G_ori, 1); c = N / 2; L = N / 3;
        plot(ax, c + [-1 1] * L * cosd(D.orient_dominante), ...
                 c + [-1 1] * L * sind(D.orient_dominante), 'r-', 'LineWidth', 3);
    end
    hold(ax, 'off');
    title(ax, sprintf('Orientación %.1f° | coherencia %.3f', ...
        D.orient_dominante, D.coherencia), 'FontSize', 9);
end

function p_conectividad(ax, E, G, D)
    base = 0.45 * double(E.Mmor);
    r = base; g = base; b = base;
    r(G.mayor) = 0.9; g(G.mayor) = 0.15; b(G.mayor) = 0.15;
    r(G.skel) = 0.1;  g(G.skel) = 0.9;  b(G.skel) = 0.1;
    image(ax, cat(3, r, g, b));
    axis(ax, 'image'); set(ax, 'XTick', [], 'YTick', []);
    title(ax, sprintf('Clúster mayor (rojo): P = %.3f | longitud %.0f \\mum', ...
        D.indice_percolacion, D.network_length_um), 'FontSize', 9);
end

function p_perfil(ax, G, D)
    filas = (1:numel(G.perfil))';
    plot(ax, G.perfil * 1e12, filas, 'Color', [0.3 0.3 0.3]); hold(ax, 'on');
    plot(ax, G.ajuste * 1e12, filas, 'r-', 'LineWidth', 1.5); hold(ax, 'off');
    set(ax, 'YDir', 'reverse', 'FontSize', 8); ylim(ax, [1 numel(filas)]);
    xlabel(ax, 'mediana por fila de E_B [pm]'); ylabel(ax, 'fila');
    title(ax, sprintf('Perfil: pend. %.2e pm/nm | RMS %.1f pm | rango %.1f pm', ...
        D.perfil_pendiente_pm_nm, D.perfil_residuo_rms_pm, D.perfil_rango_pm), 'FontSize', 9);
end

function p_tabla(ax, D, ref)
    axis(ax, 'off');
    campos = fieldnames(D);
    grupos = {1, 'DISTRIBUCIÓN'; 4, 'INTENSIDAD'; 8, 'FORMA'; ...
              12, 'ORIENTACIÓN'; 14, 'CONECTIVIDAD'; 18, 'PERFIL'};
    lineas = {};
    if isempty(ref)
        lineas{end + 1} = sprintf('%-24s %12s', 'descriptor', 'valor');
    else
        lineas{end + 1} = sprintf('%-24s %12s  %s', 'descriptor', 'valor', 'CSV');
    end
    for i = 1:numel(campos)
        g = find([grupos{:, 1}] == i, 1);
        if ~isempty(g), lineas{end + 1} = ['-- ' grupos{g, 2}]; end %#ok<AGROW>
        v = D.(campos{i});
        txt = sprintf('%-24s %12.5g', campos{i}, v);
        if ~isempty(ref) && isfield(ref, campos{i})
            r = ref.(campos{i});
            if (isnan(v) && isnan(r)) || abs(v - r) <= 1e-4 * max(abs(r), 1e-12)
                txt = [txt '  ok']; %#ok<AGROW>
            else
                txt = sprintf('%s  DIF (%.4g)', txt, r);
            end
        end
        lineas{end + 1} = txt; %#ok<AGROW>
    end
    text(ax, 0, 1, strjoin(lineas, newline), 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'FontName', 'FixedWidth', 'FontSize', 7.5, ...
        'Interpreter', 'none');
    title(ax, 'Descriptores', 'FontSize', 9);
end


% =========================================================================
% AUXILIARES
% =========================================================================
function fondo_gris(ax, mascara)
    imagesc(ax, double(mascara)); colormap(ax, [0.12 0.12 0.12; 0.6 0.6 0.6]);
    set(ax, 'CLim', [0 1]);
    axis(ax, 'image'); set(ax, 'XTick', [], 'YTick', []);
end

function ampliar(f_panel, nombre)
    f  = figure('Name', nombre, 'Color', 'w', 'NumberTitle', 'off');
    ax = axes(f);
    f_panel(ax);
end

function ref = fila_csv(T, nombre)
    ref = [];
    if isempty(T) || ~ismember('imagen', T.Properties.VariableNames), return; end
    i = find(strcmp(T.imagen, nombre), 1);
    if isempty(i), return; end
    ref = table2struct(T(i, :));
end
