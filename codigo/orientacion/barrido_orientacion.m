function barrido_orientacion()
% =========================================================================
% barrido_orientacion.m
% Barrido de los parametros del tensor de estructura (sigma_d, sigma_i) para
% verificar la ESTABILIDAD del descriptor de orientacion sobre las 81 imagenes.
%
% Para cada par (sigma_d, sigma_i) recalcula orient_dominante y coherencia en
% las 81 imagenes y reporta:
%   1) Reproducibilidad: R dentro de replica (circular). Mayor = mas estable.
%      (azar ~ 0.54; el valor en (2,8) fue 0.675, p=0.005)
%   2) Desplazamiento del angulo vs la referencia (2,8): mediana |Δθ| circular.
%      Menor = el angulo casi no cambia al mover el parametro.
%   3) Coherencia media sobre las 81.
%
% EFICIENTE: la binarizacion NO depende de sigma_d/sigma_i, asi que cada
% imagen se binariza UNA sola vez; luego solo se recalcula el tensor (barato).
%
% Salida: tabla por consola + CSV  barrido_orientacion.csv
% Uso: escribir   barrido_orientacion   en la ventana de comandos.
% =========================================================================

    clc;

    % -------------------- RUTAS (ajusta si hace falta) ---------------
    rutas = rutas_tesis();   % rutas relativas al repositorio (codigo/utils)
    inputFolder = rutas.crudos;
    outCSV      = fullfile(rutas.resultados, 'barrido_orientacion.csv');

    % -------------------- Parametros del pipeline (= Main.m) ---------
    sensibilidad = 0.55;
    pix_minimos  = 50;

    % -------------------- Grilla del barrido -------------------------
    sd_list = [1 1.5 2 3 4];      % escala de derivada (px)
    si_list = [4 6 8 12 16];      % escala de integracion (px)
    sd_ref  = 2;  si_ref = 8;     % referencia actual

    % -------------------- Lista de las 81 imagenes -------------------
    cond = {'0a','0b','0c','1a','1b','1c','2a','2b','2c'};
    nombres = {}; condIdx = []; repIdx = [];
    for c = 1:numel(cond)
        for nimg = 1:9
            nombres{end+1} = sprintf('%s-%d', cond{c}, nimg); %#ok<AGROW>
            condIdx(end+1) = c;                 %#ok<AGROW>  condicion (1..9)
            repIdx(end+1)  = ceil(nimg/3);      %#ok<AGROW>  replica (1..3): img 1-3,4-6,7-9
        end
    end
    N = numel(nombres);

    % ============ 1) BINARIZAR las 81 una sola vez ===================
    fprintf('Binarizando 81 imagenes (una sola vez)...\n');
    BWset = cell(1,N); ok = false(1,N);
    for k = 1:N
        fpath = fullfile(inputFolder, [nombres{k} '.ibw']);
        if ~exist(fpath,'file'), fprintf('  (falta %s)\n', nombres{k}); continue; end
        try
            BWset{k} = procesar_mascara(fpath, sensibilidad, pix_minimos);
            ok(k) = true;
        catch ME
            fprintf('  ERROR %s: %s\n', nombres{k}, ME.message);
        end
        if mod(k,9)==0, fprintf('  %d/%d\n', k, N); end
    end

    % ============ 2) BARRIDO del tensor ==============================
    nSD = numel(sd_list); nSI = numel(si_list);
    R_within = nan(nSD,nSI);     % reproducibilidad
    cohMean  = nan(nSD,nSI);     % coherencia media
    ANG      = nan(nSD,nSI,N);   % angulos por celda (para desplazamiento)

    fprintf('\nBarriendo %dx%d combinaciones...\n', nSD, nSI);
    for i = 1:nSD
        for j = 1:nSI
            sd = sd_list(i); si = si_list(j);
            ang = nan(1,N); coh = nan(1,N);
            for k = 1:N
                if ~ok(k), continue; end
                [ang(k), coh(k)] = orient_coh(BWset{k}, sd, si);
            end
            ANG(i,j,:) = ang;
            cohMean(i,j) = mean(coh(ok));
            % R dentro de replica (circular, periodo 180 -> angulo doblado)
            Rw = [];
            for c = 1:numel(cond)
                for r = 1:3
                    sel = ok & (condIdx==c) & (repIdx==r);
                    if sum(sel) >= 2
                        phi = 2*deg2rad(ang(sel));
                        Rw(end+1) = abs(mean(exp(1i*phi))); %#ok<AGROW>
                    end
                end
            end
            R_within(i,j) = mean(Rw);
        end
        fprintf('  sigma_d=%.1f listo\n', sd_list(i));
    end

    % desplazamiento del angulo vs referencia (2,8)
    iref = find(sd_list==sd_ref); jref = find(si_list==si_ref);
    angRef = squeeze(ANG(iref,jref,:));
    angShift = nan(nSD,nSI);
    for i = 1:nSD
        for j = 1:nSI
            a = squeeze(ANG(i,j,:));
            d = abs(a - angRef); d = mod(d,180); d = min(d,180-d);  % dist circular
            angShift(i,j) = median(d(ok));
        end
    end

    % ============ 3) IMPRIMIR TABLAS =================================
    print_grid('REPRODUCIBILIDAD  R dentro de replica  (mayor = mas estable; azar~0.54)', ...
               R_within, sd_list, si_list, sd_ref, si_ref, '%6.3f');
    print_grid('DESPLAZAMIENTO del angulo vs (2,8)  mediana |dtheta| en grados (menor = mas estable)', ...
               angShift, sd_list, si_list, sd_ref, si_ref, '%6.1f');
    print_grid('COHERENCIA media sobre las 81', ...
               cohMean, sd_list, si_list, sd_ref, si_ref, '%6.3f');

    % ============ 4) GUARDAR CSV =====================================
    outDir = fileparts(outCSV);
    if ~isempty(outDir) && ~exist(outDir,'dir'), mkdir(outDir); end
    fid = fopen(outCSV,'w');
    fprintf(fid,'sigma_d,sigma_i,R_within_replica,desplazamiento_angulo_deg,coherencia_media\n');
    for i = 1:nSD
        for j = 1:nSI
            fprintf(fid,'%.2f,%.2f,%.4f,%.4f,%.4f\n', ...
                sd_list(i), si_list(j), R_within(i,j), angShift(i,j), cohMean(i,j));
        end
    end
    fclose(fid);
    fprintf('\nCSV guardado -> %s\n', outCSV);
    fprintf('Referencia actual: sigma_d=%.1f, sigma_i=%.1f\n', sd_ref, si_ref);
end


% =========================================================================
% Imprime una grilla sd x si con la celda de referencia marcada
% =========================================================================
function print_grid(titulo, M, sd_list, si_list, sd_ref, si_ref, fmt)
    fprintf('\n=== %s ===\n', titulo);
    fprintf('%8s','');
    for j = 1:numel(si_list), fprintf(' si=%-5.0f', si_list(j)); end
    fprintf('\n');
    for i = 1:numel(sd_list)
        fprintf('sd=%-5.1f', sd_list(i));
        for j = 1:numel(si_list)
            s = sprintf(fmt, M(i,j));
            if sd_list(i)==sd_ref && si_list(j)==si_ref
                fprintf(' %s*', strtrim(s));   % * marca la referencia
            else
                fprintf(' %s ', strtrim(s));
            end
        end
        fprintf('\n');
    end
    fprintf('(* = referencia actual sd=%.1f, si=%.1f)\n', sd_ref, si_ref);
end


% =========================================================================
% Orientacion y coherencia para una mascara dada (IDENTICO a Main.m corregido)
% =========================================================================
function [orient, coh] = orient_coh(BW2_closed, sigma_d, sigma_i)
    G_ori = imgaussfilt(double(BW2_closed), sigma_d);
    [Gx_o, Gy_o] = gradient(G_ori);          % MATLAB: [FX, FY] = [d/dx, d/dy]
    Jxx_m = imgaussfilt(Gx_o.^2,     sigma_i);
    Jyy_m = imgaussfilt(Gy_o.^2,     sigma_i);
    Jxy_m = imgaussfilt(Gx_o.*Gy_o,  sigma_i);
    roi = BW2_closed;
    Sxx = sum(Jxx_m(roi)); Syy = sum(Jyy_m(roi)); Sxy = sum(Jxy_m(roi));
    if sum(roi(:)) > 10 && (Sxx + Syy) > 0
        orient = 0.5 * atan2d(2*Sxy, Sxx - Syy);
        orient = mod(orient + 90, 180);
        l1 = 0.5*(Sxx+Syy) + 0.5*sqrt((Sxx-Syy)^2 + 4*Sxy^2);
        l2 = 0.5*(Sxx+Syy) - 0.5*sqrt((Sxx-Syy)^2 + 4*Sxy^2);
        coh = (l1 - l2) / (l1 + l2);
    else
        orient = NaN; coh = NaN;
    end
end


% =========================================================================
% Pipeline hasta BW2_closed (= Main.m, sin la parte de orientacion)
% =========================================================================
function BW2_closed = procesar_mascara(fp, sens, pix_minimos)
    Full = IBWread(fp);
    Elec_Raw = rot90(double(Full.y(:,:,5)));
    Topo     = rot90(double(Full.y(:,:,1)));
    if ~isequal(size(Elec_Raw), size(Topo))
        Elec_Raw = imresize(Elec_Raw, size(Topo));
    end

    En = (Elec_Raw - median(Elec_Raw(:))) / mad(Elec_Raw(:),1);
    Tn = (Topo     - median(Topo(:)))     / mad(Topo(:),1);
    [Gy,Gx] = gradient(Tn);
    X  = [Tn(:), Gx(:), Gy(:), ones(numel(Tn),1)];
    b  = X \ En(:);
    Efit = reshape(X*b, size(En));

    Ec   = En - Efit;
    E1   = Etapa1_SyP_Selectivo(Ec, [5 5], 3);
    Es   = line_strip_correction(E1);
    Ecl  = Etapa1_SyP_Selectivo(Es, [5 1], 2);
    Eseg = rescale_1_99(Ecl);
    th   = multithresh(Eseg, 6);
    BW1  = bwareaopen(Eseg >= th(1), pix_minimos);
    Tr   = adaptthresh(Eseg, sens, 'NeighborhoodSize',[51 51], 'Statistic','gaussian', 'ForegroundPolarity','bright');
    Tl   = adaptthresh(Eseg, sens, 'NeighborhoodSize',[21 21], 'Statistic','gaussian', 'ForegroundPolarity','bright');
    BW2  = bwareaopen(BW1 & imbinarize(Eseg,Tr) & imbinarize(Eseg,Tl), pix_minimos);
    if sum(BW2(:))/numel(BW2) < 0.15
        Tf  = adaptthresh(Eseg, 0.55, 'NeighborhoodSize',[21 21], 'Statistic','gaussian', 'ForegroundPolarity','bright');
        BW2 = bwareaopen(imbinarize(Eseg,Tf), 50);
    end
    BW2_closed = imclose(BW2, strel('disk',3));
end


% =========================================================================
% FUNCIONES LOCALES (identicas a Main.m)
% =========================================================================
function I_out = line_strip_correction(I_in)
    [r, ~] = size(I_in);
    I_out  = zeros(size(I_in));
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
    Img_Vis(Img_Vis < 0) = 0;
    Img_Vis(Img_Vis > 1) = 1;
end
