function diagnostico_orientacion()
% DIAGNOSTICO_ORIENTACION  Script autocontenido (un solo archivo, un solo CSV).
%
% Reproduce el pipeline de binarizacion de Main.m hasta BW2_closed y, por cada
% imagen, calcula TRES formas de agregar la orientacion mas dos metricas de
% sesgo de grilla. Escribe orientacion_diagnostico.csv (DISTINTO de
% descriptores.csv) e imprime el veredicto en consola.
%
% NO edita Main.m y NO necesita orient_diagnostico.m: ignora ambos.
%
% Columnas del CSV (una fila por imagen):
%   orient_A_deg, coh_A : metodo ACTUAL (suma cartesiana del tensor, energia)
%   orient_B_deg, R_B   : area + tensor por componente   (orientacion, magnitud)
%   orient_C_deg, R_C   : area + ELIPSE por componente    (orientacion, magnitud)
%   gridfrac_tensor_comp: frac. de componentes a +-15 de 0/90/180 (tensor)
%   gridfrac_elipse_comp: idem con la elipse  <- referencia robusta a la grilla
%
% CHEQUEO AUTOMATICO: orient_A_deg debe COINCIDIR con orient_dominante de
% descriptores.csv. Si la diferencia axial maxima es ~0, la mascara reproducida
% es identica a la de Main.m y todo lo demas es de fiar.

clc;

% ------------------- CONFIG (rutas ya puestas como en Main.m) -------------
rutas = rutas_tesis();   % rutas relativas al repositorio (codigo/utils)
inputFolder = rutas.crudos;
outputCSV   = fullfile(rutas.resultados, 'orientacion_diagnostico.csv');
refCSV      = fullfile(rutas.resultados, 'descriptores.csv');   % para el sanity

sensibilidad = 0.55;
pix_minimos  = 50;
sigma_d      = 2;     % escala de derivada    (igual que tu orientacion)
sigma_i      = 8;     % escala de integracion (igual que tu orientacion)
min_area     = 50;    % area minima de componente para la distribucion por-comp.

ibwFiles = dir(fullfile(inputFolder,'*.ibw'));
outDir = fileparts(outputCSV); if ~exist(outDir,'dir'), mkdir(outDir); end

setenv('LC_NUMERIC','C')
fid = fopen(outputCSV,'w');
fprintf(fid, ['imagen,voltaje_V,frecuencia_Hz,replica,posicion,'...
    'orient_A_deg,coh_A,orient_B_deg,R_B,orient_C_deg,R_C,'...
    'gridfrac_tensor_comp,gridfrac_elipse_comp,n_componentes,signo_elipse\n']);

% acumuladores para el veredicto
allA=[]; allB=[]; allC=[]; gtc=[]; gec=[]; RB=[]; RC=[];
imgNames = {}; orientA_vec = [];

for k = 1:numel(ibwFiles)
    filename = ibwFiles(k).name;
    try
        Full_data = IBWread(fullfile(inputFolder, filename));
        Elec_Raw  = rot90(double(Full_data.y(:,:,5)));
        Topo      = rot90(double(Full_data.y(:,:,1)));
        if ~isequal(size(Elec_Raw), size(Topo))
            Elec_Raw = imresize(Elec_Raw, size(Topo));
        end

        % ----- crosstalk (identico a Main.m) -----
        Elec_norm = (Elec_Raw - median(Elec_Raw(:))) / mad(Elec_Raw(:),1);
        Topo_norm = (Topo     - median(Topo(:)))     / mad(Topo(:),1);
        [Gy, Gx]  = gradient(Topo_norm);
        X    = [Topo_norm(:), Gx(:), Gy(:), ones(numel(Topo_norm),1)];
        beta = X \ Elec_norm(:);
        Elec_fit = reshape(X*beta, size(Elec_norm));

        % ----- binarizacion -> BW2 -> BW2_closed (identico a Main.m) -----
        Elec_corr = Elec_norm - Elec_fit;
        Elec_c1   = SyP_Selectivo(Elec_corr, [5 5], 3);
        Elec_str  = line_strip_correction(Elec_c1);
        Elec_cln  = SyP_Selectivo(Elec_str, [5 1], 2);
        Eseg      = rescale_1_99(Elec_cln);

        thresh = multithresh(Eseg, 6);
        BW1    = bwareaopen(Eseg >= thresh(1), pix_minimos);
        T_reg  = adaptthresh(Eseg, sensibilidad, 'NeighborhoodSize',[51 51], ...
                 'Statistic','gaussian','ForegroundPolarity','bright');
        BW_reg = imbinarize(Eseg, T_reg);
        T_loc  = adaptthresh(Eseg, sensibilidad, 'NeighborhoodSize',[21 21], ...
                 'Statistic','gaussian','ForegroundPolarity','bright');
        BW_loc = imbinarize(Eseg, T_loc);
        BW2    = bwareaopen(BW1 & BW_reg & BW_loc, pix_minimos);
        cob    = sum(BW2(:))/numel(BW2);
        if cob < 0.15
            T_fb = adaptthresh(Eseg, 0.55, 'NeighborhoodSize',[21 21], ...
                   'Statistic','gaussian','ForegroundPolarity','bright');
            BW2  = bwareaopen(imbinarize(Eseg, T_fb), 50);
        end
        BW2_closed = imclose(BW2, strel('disk', 3));

        % ----- metricas de orientacion A/B/C + sesgo -----
        M = metrica_orientacion(BW2_closed, sigma_d, sigma_i, min_area);

        % ----- fabricacion -----
        [v, f, rep, pos] = parsear_fabricacion(filename);

        fprintf(fid, '%s,%g,%g,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%s\n', ...
            filename, v, f, rep, pos, M.orient_A, M.coh_A, M.orient_B, M.R_B, ...
            M.orient_C, M.R_C, M.gridfrac_t, M.gridfrac_e, M.nComp, M.signo);

        allA(end+1)=M.orient_A; allB(end+1)=M.orient_B; allC(end+1)=M.orient_C; %#ok<AGROW>
        gtc(end+1)=M.gridfrac_t; gec(end+1)=M.gridfrac_e; %#ok<AGROW>
        RB(end+1)=M.R_B; RC(end+1)=M.R_C; %#ok<AGROW>
        imgNames{end+1}=filename; orientA_vec(end+1)=M.orient_A; %#ok<AGROW>

        fprintf('Procesado %d/%d: %s\n', k, numel(ibwFiles), filename);
    catch ME
        fprintf('Error en %s: %s\n', filename, ME.message);
    end
end
fclose(fid);

% ========================= VEREDICTO (consola) =========================
gn = @(th) mean( (mod(th(:),180)<=15) | (mod(th(:),180)>=165) | (abs(mod(th(:),180)-90)<=15) );
fprintf('\n================ VEREDICTO ================\n');
fprintf('POR COMPONENTE (promedio sobre imagenes; +-15 de 0/90/180, uniforme ~33%%):\n');
fprintf('   tensor : %.0f%%\n', 100*mean(gtc,'omitnan'));
fprintf('   elipse : %.0f%%   <- referencia robusta a la grilla\n', 100*mean(gec,'omitnan'));
fprintf('GLOBAL POR IMAGEN (concentracion a +-15 de 0/90/180):\n');
fprintf('   (A) suma cartesiana ACTUAL       : %.0f%%\n', 100*gn(allA));
fprintf('   (B) area + tensor por componente : %.0f%%\n', 100*gn(allB));
fprintf('   (C) area + elipse  por componente: %.0f%%\n', 100*gn(allC));
fprintf('ALINEAMIENTO (R axial pesado por area): mediana R_B=%.3f | R_C=%.3f\n', ...
        median(RB,'omitnan'), median(RC,'omitnan'));
fprintf('   (R~0 => sin direccion colectiva real;  R~1 => segmentos alineados)\n');

% ---- sanity automatico: orient_A vs orient_dominante de descriptores.csv ----
if exist(refCSV,'file')
    try
        Tref = readtable(refCSV);
        d = nan(1,numel(imgNames));
        for i = 1:numel(imgNames)
            r = strcmp(string(Tref.imagen), imgNames{i});
            if any(r)
                a = orientA_vec(i);  b = Tref.orient_dominante(find(r,1));
                if isfinite(a) && isfinite(b)
                    dd = mod(a-b,180);  d(i) = min(dd,180-dd);   % diferencia axial
                end
            end
        end
        fprintf('SANITY  orient_A vs orient_dominante (descriptores.csv): max dif axial = %.4f deg\n', max(d));
        fprintf('        (debe ser ~0; si es grande, la mascara reproducida difiere de Main.m)\n');
    catch ME2
        fprintf('SANITY: no se pudo comparar con %s (%s)\n', refCSV, ME2.message);
    end
else
    fprintf('SANITY: %s no encontrado; compara a mano orient_A_deg vs orient_dominante.\n', refCSV);
end

fprintf('\nCSV escrito -> %s\n', outputCSV);
end


% =========================== SUBFUNCIONES ===========================
function M = metrica_orientacion(BW2_closed, sigma_d, sigma_i, min_area)
    BW = logical(BW2_closed);
    G  = imgaussfilt(double(BW), sigma_d);
    [Gx, Gy] = gradient(G);
    Jxx = imgaussfilt(Gx.^2,  sigma_i);
    Jyy = imgaussfilt(Gy.^2,  sigma_i);
    Jxy = imgaussfilt(Gx.*Gy, sigma_i);

    props = regionprops(BW, 'Area','Orientation','PixelIdxList');
    nC = numel(props);
    if nC == 0
        M = struct('orient_A',NaN,'coh_A',NaN,'orient_B',NaN,'R_B',NaN, ...
                   'orient_C',NaN,'R_C',NaN,'gridfrac_t',NaN,'gridfrac_e',NaN, ...
                   'nComp',0,'signo','+');  return;
    end
    theta_t = nan(nC,1);  theta_e = nan(nC,1);  area_c = nan(nC,1);
    Sxx = 0; Syy = 0; Sxy = 0;
    for c = 1:nC
        idx = props(c).PixelIdxList;
        sx = sum(Jxx(idx));  sy = sum(Jyy(idx));  sxy = sum(Jxy(idx));
        Sxx = Sxx+sx;  Syy = Syy+sy;  Sxy = Sxy+sxy;
        theta_t(c) = mod(0.5*atan2d(2*sxy, sx-sy) + 90, 180);
        theta_e(c) = props(c).Orientation;
        area_c(c)  = props(c).Area;
    end
    orient_A = mod(0.5*atan2d(2*Sxy, Sxx-Syy) + 90, 180);
    l1 = 0.5*(Sxx+Syy) + 0.5*sqrt((Sxx-Syy)^2 + 4*Sxy^2);
    l2 = 0.5*(Sxx+Syy) - 0.5*sqrt((Sxx-Syy)^2 + 4*Sxy^2);
    coh_A = (l1-l2)/(l1+l2+eps);

    keep = area_c >= min_area;  tt = theta_t(keep);  te = theta_e(keep);  ar = area_c(keep);
    te_pos = mod( te,180);  te_neg = mod(-te,180);
    if median(axdiff(tt,te_neg)) < median(axdiff(tt,te_pos))
        te_use = te_neg;  signo = '-';
    else
        te_use = te_pos;  signo = '+';
    end
    [orient_B,R_B] = axial_resultant(tt,     ar);
    [orient_C,R_C] = axial_resultant(te_use, ar);

    M = struct('orient_A',orient_A,'coh_A',coh_A,'orient_B',orient_B,'R_B',R_B, ...
               'orient_C',orient_C,'R_C',R_C,'gridfrac_t',gridfrac(tt), ...
               'gridfrac_e',gridfrac(te_use),'nComp',sum(keep),'signo',signo);
end

function d = axdiff(a,b)
    d = mod(a-b,180);  d = min(d, 180-d);
end

function [ang,R] = axial_resultant(theta_deg, w)
    th = theta_deg(:);  w = w(:);  ok = isfinite(th) & isfinite(w);
    if ~any(ok) || sum(w(ok))==0, ang = NaN; R = NaN; return; end
    z   = sum(w(ok).*exp(1i*2*deg2rad(th(ok)))) / sum(w(ok));
    ang = mod(rad2deg(0.5*angle(z)), 180);  R = abs(z);
end

function f = gridfrac(theta_deg)
    th = mod(theta_deg(:),180);  if isempty(th), f = NaN; return; end
    f = mean( (th<=15) | (th>=165) | (abs(th-90)<=15) );
end

function I_Out = SyP_Selectivo(I_In, kernel_size, n_sigmas)
    Fondo_Ref = medfilt2(I_In, kernel_size);
    Residuo   = abs(I_In - Fondo_Ref);
    sigma_r   = median(Residuo(:)) / 0.6745;
    Mala      = Residuo > (n_sigmas * sigma_r);
    I_Out     = I_In;  I_Out(Mala) = Fondo_Ref(Mala);
end

function I_out = line_strip_correction(I_in)
    [r,~] = size(I_in);  I_out = zeros(size(I_in));
    for i = 1:r
        row = I_in(i,:);  sigma = mad(row,1);
        dyn = prctile(row,95) - prctile(row,5);  ratio = sigma/dyn;
        p   = max(25, min(45, 40 - 20*ratio));  cutoff = prctile(row, p);
        bg  = row(row <= cutoff);
        if isempty(bg), offset = median(row); else, offset = median(bg); end
        I_out(i,:) = row - offset;
    end
end

function Img = rescale_1_99(Data)
    li = prctile(Data(:),1);  ls = prctile(Data(:),99);
    if ls == li, Img = zeros(size(Data)); return; end
    Img = (Data - li)/(ls - li);  Img(Img<0) = 0;  Img(Img>1) = 1;
end

function [v,f,rep,pos] = parsear_fabricacion(filename)
    v = NaN; f = NaN; rep = NaN; pos = NaN;
    [~,nombre,~] = fileparts(filename);
    tok = regexp(nombre, '^([0-2])([abc])-([1-9])$', 'tokens');
    if isempty(tok), return; end
    switch tok{1}{1}
        case '0', v = 5;
        case '1', v = 10;
        case '2', v = 15;
    end
    switch tok{1}{2}
        case 'a', f = 10;
        case 'b', f = 1000;
        case 'c', f = 100000;
    end
    n = str2double(tok{1}{3});  rep = ceil(n/3);  pos = mod(n-1,3)+1;
end
