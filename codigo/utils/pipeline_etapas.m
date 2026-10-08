function E = pipeline_etapas(ruta, P)
% PIPELINE_ETAPAS  Ejecuta el pipeline de pipeline/Descriptores_Final.m sobre
% una imagen .ibw y devuelve cada etapa intermedia en una estructura.
%
%   E = pipeline_etapas(ruta)      usa parametros_pipeline()
%   E = pipeline_etapas(ruta, P)
%
% Campos principales: Eraw, Topo, Ecorr, E1, Efondo, Eclean, Eseg,
% ML, MG, MR, Me, Mmor, sk (esqueleto), EB (en metros), perfil_V,
% tendencia_V, respaldo, cobertura, Nc_e, Nc_mor, r_ET, R_mult.
    if nargin < 2, P = parametros_pipeline(); end
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
    E.Me = Me;       E.Mmor = Mmor;   E.sk = sk;   E.rgb_skel = cat(3, rr, gg, bb);
    E.EB = EB;       E.perfil_V = pV; E.tendencia_V = tV;
    E.cobertura = nnz(Me) / numel(Me);
    E.Nc_e   = bwconncomp(Me).NumObjects;
    E.Nc_mor = bwconncomp(Mmor).NumObjects;
end


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
