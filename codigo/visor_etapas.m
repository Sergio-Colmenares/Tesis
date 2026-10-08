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

        [vV, fHz, rep, pos] = parsear_fabricacion(nombres{k});
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
% PARÁMETROS (idénticos a pipeline/Descriptores_Final.m)
% =========================================================================
function P = parametros_pipeline()
    P.sens = 0.55;   % sensibilidad de adaptthresh
    P.pmin = 50;     % área mínima por componente [px]
    P.otsu = 6;      % número de umbrales de multithresh
    P.vL   = 21;     % NeighborhoodSize local (actúa como sigma)
    P.vR   = 51;     % NeighborhoodSize regional (actúa como sigma)
    P.ufb  = 0.15;   % cobertura mínima antes del respaldo
    P.r    = 3;      % radio del cierre morfológico [px]
    P.spur = 5;      % iteraciones de poda del esqueleto
    P.w    = 50;     % ventana RLOESS [filas]
end


% =========================================================================
% PIPELINE COMPLETO DE UNA IMAGEN, GUARDANDO CADA ETAPA
% =========================================================================
function E = pipeline_etapas(ruta, P)
    Full = IBWread(ruta);
    Eraw = rot90(double(Full.y(:, :, 5)));
    Topo = rot90(double(Full.y(:, :, 1)));
    if ~isequal(size(Eraw), size(Topo))
        Eraw = imresize(Eraw, size(Topo));
    end

    % Corrección de crosstalk topográfico
    En = (Eraw - median(Eraw(:))) / mad(Eraw(:), 1);
    Tn = (Topo - median(Topo(:))) / mad(Topo(:), 1);
    [Gx, Gy] = gradient(Tn);
    X    = [Tn(:), Gx(:), Gy(:), ones(numel(Tn), 1)];
    beta = X \ En(:);
    Efit = reshape(X * beta, size(En));
    Ecorr = En - Efit;

    c = corrcoef(En(:), Tn(:));
    E.r_ET   = c(1, 2);
    e_c      = En(:) - mean(En(:));
    E.R_mult = sqrt(max(0, 1 - sum(Ecorr(:).^2) / sum(e_c.^2)));

    % Limpieza y normalización
    E1     = SyP_selectivo(Ecorr, [5 5], 3);
    Efondo = correccion_fondo(E1);
    Eclean = SyP_selectivo(Efondo, [5 1], 2);
    Eseg   = rescale_1_99(Eclean);

    % Binarizaciones
    th = multithresh(Eseg, P.otsu);
    MG = Eseg >= th(1);
    TR = adaptthresh(Eseg, P.sens, 'NeighborhoodSize', [P.vR P.vR], ...
        'Statistic', 'gaussian', 'ForegroundPolarity', 'bright');
    MR = imbinarize(Eseg, TR);
    TL = adaptthresh(Eseg, P.sens, 'NeighborhoodSize', [P.vL P.vL], ...
        'Statistic', 'gaussian', 'ForegroundPolarity', 'bright');
    ML = imbinarize(Eseg, TL);

    Me = bwareaopen(bwareaopen(MG, P.pmin) & MR & ML, P.pmin);
    E.respaldo = nnz(Me) / numel(Me) < P.ufb;
    if E.respaldo
        Me = bwareaopen(ML, P.pmin);
    end
    Mmor = imclose(Me, strel('disk', P.r));
    sk   = bwmorph(bwskel(Mmor), 'spur', P.spur);

    % Imagen eléctrica reconstruida E_B
    EcB  = Eraw - Efit .* mad(Eraw(:), 1);
    Esy  = SyP_selectivo(EcB, [5 5], 3);
    pV   = median(Esy, 2);
    tV   = smoothdata(pV, 'rloess', P.w);
    EB   = Esy - (pV - tV);

    % Esqueleto en rojo sobre M_mor en gris
    base = 0.55 * double(Mmor);
    rr = base; gg = base; bb = base;
    rr(sk) = 1; gg(sk) = 0.1; bb(sk) = 0.1;

    E.Eraw = Eraw;   E.Topo = Topo;   E.Ecorr = Ecorr;
    E.E1 = E1;       E.Efondo = Efondo; E.Eclean = Eclean; E.Eseg = Eseg;
    E.ML = ML;       E.MG = MG;       E.MR = MR;
    E.Me = Me;       E.Mmor = Mmor;   E.rgb_skel = cat(3, rr, gg, bb);
    E.EB = EB;       E.perfil_V = pV; E.tendencia_V = tV;
    E.cobertura = nnz(Me) / numel(Me);
    E.Nc_e   = bwconncomp(Me).NumObjects;
    E.Nc_mor = bwconncomp(Mmor).NumObjects;
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


% =========================================================================
% FUNCIONES DEL PIPELINE (copiadas de pipeline/Descriptores_Final.m)
% =========================================================================
function I_out = SyP_selectivo(I_in, kernel, n_sigmas)
    M     = medfilt2(I_in, kernel);
    R     = abs(I_in - M);
    sigma = median(R(:)) / 0.6745;
    malos = R > (n_sigmas * sigma);
    I_out = I_in;
    I_out(malos) = M(malos);
end

function I_out = correccion_fondo(I_in)
    I_out = zeros(size(I_in));
    for i = 1:size(I_in, 1)
        fila   = I_in(i, :);
        ratio  = mad(fila, 1) / (prctile(fila, 95) - prctile(fila, 5));
        p      = max(25, min(45, 40 - 20 * ratio));
        fondo  = fila(fila <= prctile(fila, p));
        if isempty(fondo)
            offset = median(fila);
        else
            offset = median(fondo);
        end
        I_out(i, :) = fila - offset;
    end
end

function I_out = rescale_1_99(D)
    lo = prctile(D(:), 1);
    hi = prctile(D(:), 99);
    if hi == lo
        I_out = zeros(size(D));
        return;
    end
    I_out = max(0, min(1, (D - lo) / (hi - lo)));
end

function [voltaje_V, frecuencia_Hz, replica, posicion] = parsear_fabricacion(nombre_archivo)
    voltaje_V = NaN; frecuencia_Hz = NaN; replica = NaN; posicion = NaN;
    [~, nombre] = fileparts(nombre_archivo);
    tok = regexp(nombre, '^([0-2])([abc])-([1-9])$', 'tokens');
    if isempty(tok), return; end
    voltajes    = [5 10 15];
    frecuencias = [10 1000 100000];
    voltaje_V     = voltajes(str2double(tok{1}{1}) + 1);
    frecuencia_Hz = frecuencias(tok{1}{2} - 'a' + 1);
    n        = str2double(tok{1}{3});
    replica  = ceil(n / 3);
    posicion = mod(n - 1, 3) + 1;
end
