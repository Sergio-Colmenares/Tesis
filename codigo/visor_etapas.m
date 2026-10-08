function visor_etapas(k0)
% VISOR_ETAPAS  Visor interactivo del pipeline, etapa por etapa.
%
%   visor_etapas            abre la primera imagen de datos/crudos
%   visor_etapas(k)         abre la imagen número k (orden alfabético)
%   visor_etapas('2b-5')    abre la imagen con ese nombre
%
% Muestra, para una imagen, las 15 etapas del pipeline de
% pipeline/Descriptores_Final.m con los mismos parámetros:
%   canal eléctrico crudo, topografía, crosstalk, SyP 5x5, fondo por fila,
%   SyP 5x1, E_seg, M_L, M_G, M_R, M_e, M_mor, esqueleto, E_B y el perfil
%   vertical de la corrección RLOESS.
%
% Navegación:
%   flechas izquierda/derecha (o los botones)  imagen anterior/siguiente
%   clic sobre un panel                        abre ese panel en grande
%   zoom/desplazamiento                        sincronizados entre paneles
%
% Requiere: Image Processing Toolbox y Statistics and Machine Learning
% Toolbox. Correr antes configurar (o addpath(genpath('codigo'))).

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

    fig = figure('Name', 'Visor de etapas del pipeline', 'Color', 'w', ...
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
        delete(findall(fig, 'Type', 'axes'));

        [vV, fHz, rep, pos] = parsear_fabricacion_ibw(nombres{k});
        txt_resp = 'no';
        if E.respaldo, txt_resp = 'SI'; end
        set(info, 'String', sprintf(['[%d/%d]  %s   |   %g V, %g Hz, réplica %d, ' ...
            'posición %d   |   cobertura M_e = %.1f %%   |   Nc(M_e) = %d, ' ...
            'Nc(M_mor) = %d   |   respaldo: %s   |   r(E,T) = %.3f, R crosstalk = %.3f'], ...
            k, numel(nombres), nombres{k}, vV, fHz, rep, pos, 100 * E.cobertura, ...
            E.Nc_e, E.Nc_mor, txt_resp, E.r_ET, E.R_mult));

        titulo_Me = 'M_e = M_L \wedge M_G \wedge M_R';
        if E.respaldo, titulo_Me = 'M_e (RESPALDO: solo M_L)'; end

        % {datos, título (TeX), tipo}
        paneles = {
            E.Eraw,         'Canal eléctrico crudo (\partial C/\partial z)', 'cont'
            E.Topo,         'Topografía',                                   'cont'
            E.Ecorr,        'Crosstalk corregido',                          'cont'
            E.E1,           'SyP 5\times5 (n = 3)',                         'cont'
            E.Efondo,       'Fondo por fila',                               'cont'
            E.Eclean,       'SyP 5\times1 vertical (n = 2)',                'cont'
            E.Eseg,         'E_{seg} (P1-P99)',                             'cont'
            E.ML,           sprintf('M_L local (\\sigma = %d px)', P.vL),   'bin'
            E.MG,           sprintf('M_G Otsu (%d umbrales)', P.otsu),     'bin'
            E.MR,           sprintf('M_R regional (\\sigma = %d px)', P.vR),'bin'
            E.Me,           titulo_Me,                                      'bin'
            E.Mmor,         sprintf('M_{mor} (cierre r = %d px)', P.r),    'bin'
            E.rgb_skel,     sprintf('Esqueleto (poda %d)', P.spur),        'rgb'
            E.EB * 1e12,    'E_B [pm]',                                     'cont'
            };

        ejes = gobjects(size(paneles, 1), 1);
        for i = 1:size(paneles, 1)
            ax = subplot(3, 5, i, 'Parent', fig);
            mostrar(ax, paneles{i, 1}, paneles{i, 3}, cmap);
            title(ax, paneles{i, 2}, 'FontSize', 9);
            hijos = get(ax, 'Children');
            set(hijos, 'ButtonDownFcn', @(~, ~) ampliar(paneles{i, 1}, ...
                [nombres{k} ' - ' paneles{i, 2}], paneles{i, 3}, cmap));
            ejes(i) = ax;
        end
        linkaxes(ejes, 'xy');

        % Panel 15: perfil vertical antes y después de la corrección RLOESS
        ax = subplot(3, 5, 15, 'Parent', fig);
        filas = (1:numel(E.perfil_V))';
        plot(ax, E.perfil_V * 1e12, filas, 'Color', [0.6 0.6 0.6]); hold(ax, 'on');
        plot(ax, E.tendencia_V * 1e12, filas, 'r', 'LineWidth', 1.5);
        hold(ax, 'off');
        set(ax, 'YDir', 'reverse', 'FontSize', 8);
        ylim(ax, [1 numel(filas)]);
        xlabel(ax, 'mediana por fila [pm]'); ylabel(ax, 'fila');
        legend(ax, {'original', 'tendencia RLOESS'}, 'Location', 'best', 'FontSize', 7);
        title(ax, sprintf('Perfil vertical (RLOESS %d filas)', P.w), 'FontSize', 9);

        set(fig, 'Pointer', 'arrow');
    end
end


% =========================================================================
% VISUALIZACIÓN
% =========================================================================
function mostrar(ax, datos, tipo, cmap)
    switch tipo
        case 'rgb'
            image(ax, datos);
        case 'bin'
            imagesc(ax, double(datos));
            colormap(ax, gray(2));
            set(ax, 'CLim', [0 1]);
        otherwise
            imagesc(ax, datos);
            colormap(ax, cmap);
            set(ax, 'CLim', limites(datos));
    end
    axis(ax, 'image', 'off');
end

function ampliar(datos, titulo, tipo, cmap)
    f  = figure('Name', titulo, 'Color', 'w', 'NumberTitle', 'off');
    ax = axes(f);
    mostrar(ax, datos, tipo, cmap);
    title(ax, titulo);
    if strcmp(tipo, 'cont')
        colorbar(ax);
    end
end

function L = limites(A)
    L = prctile(A(:), [1 99]);
    if ~(L(2) > L(1))
        L = [min(A(:)), max(A(:)) + eps];
    end
end
