function estabilidad_vs_coherencia()
% =========================================================================
% estabilidad_vs_coherencia.m  (version con escalas intermedias)
% Analiza, imagen por imagen, como evoluciona el angulo de orientacion al
% variar sigma_d, y lo cruza con la coherencia.
%
% Para cada una de las 81 imagenes calcula el angulo a CINCO escalas
%   sigma_d = [1.5, 2, 2.5, 3, 4]   (sigma_i fijo = 8)
% y reporta:
%   - coherencia (a sigma_d=2, la de referencia)
%   - el angulo en cada escala (theta_sd1.5, ... , theta_sd4)
%   - dispersion_total: rango circular del angulo en todo el barrido (max-min)
%   - salto_max_consec: el mayor salto entre dos escalas CONSECUTIVAS
%     (distingue desviacion suave de brinco brusco)
%
% Guarda CSV  estabilidad_vs_coherencia.csv  con todo, por imagen.
% EFICIENTE: binariza cada imagen UNA vez; el tensor por escala es barato.
% Uso: escribir   estabilidad_vs_coherencia   en la ventana de comandos.
% =========================================================================

    clc;
    rutas = rutas_tesis();   % rutas relativas al repositorio (codigo/utils)
    inputFolder = rutas.crudos;
    outCSV      = fullfile(rutas.resultados, 'estabilidad_vs_coherencia.csv');
    sensibilidad = 0.55; pix_minimos = 50;
    sigma_i = 8;
    sd_list = [1.5 2 2.5 3 4];     % escalas de derivada (intermedias)
    sd_ref  = 2;                    % escala de referencia para la coherencia

    cond = {'0a','0b','0c','1a','1b','1c','2a','2b','2c'};
    nombres = {};
    for c = 1:numel(cond)
        for nimg = 1:9, nombres{end+1} = sprintf('%s-%d', cond{c}, nimg); end %#ok<AGROW>
    end
    N = numel(nombres); nS = numel(sd_list);
    iref = find(sd_list==sd_ref);

    fprintf('Procesando 81 imagenes en %d escalas de sigma_d...\n', nS);
    ANG = nan(N,nS);     % angulo de cada imagen en cada escala
    coh = nan(1,N);      % coherencia (a sd_ref)
    for k = 1:N
        fpath = fullfile(inputFolder,[nombres{k} '.ibw']);
        if ~exist(fpath,'file'), fprintf('  (falta %s)\n',nombres{k}); continue; end
        try
            BW = procesar_mascara(fpath, sensibilidad, pix_minimos);   % binariza UNA vez
            for j = 1:nS
                [a, c] = orient_coh(BW, sd_list(j), sigma_i);
                ANG(k,j) = a;
                if j==iref, coh(k) = c; end
            end
        catch ME
            fprintf('  ERROR %s: %s\n',nombres{k},ME.message);
        end
        if mod(k,9)==0, fprintf('  %d/%d\n',k,N); end
    end

    % --- metricas de trayectoria por imagen ---
    dispersion_total = nan(1,N);
    salto_max_consec = nan(1,N);
    for k = 1:N
        a = ANG(k,:);
        if all(isnan(a)), continue; end
        dmax = 0;
        for p = 1:nS
            for q = p+1:nS
                d = abs(a(p)-a(q)); d = mod(d,180); d = min(d,180-d);
                if d>dmax, dmax = d; end
            end
        end
        dispersion_total(k) = dmax;
        smax = 0;
        for p = 1:nS-1
            d = abs(a(p)-a(p+1)); d = mod(d,180); d = min(d,180-d);
            if d>smax, smax = d; end
        end
        salto_max_consec(k) = smax;
    end

    % --- resumen por grupos de coherencia ---
    val = ~isnan(coh);
    lo  = val & (coh < 0.05);
    md  = val & (coh >= 0.05) & (coh <= 0.10);
    hi  = val & (coh > 0.10);
    rep = @(m) sprintf('mediana=%.1f deg  max=%.1f deg  (n=%d)', median(dispersion_total(m)), max(dispersion_total(m)), sum(m));
    fprintf('\n=== Dispersion total del angulo en el barrido de sigma_d, por coherencia ===\n');
    fprintf('  coherencia < 0.05      : %s\n', rep(lo));
    fprintf('  coherencia 0.05-0.10   : %s\n', rep(md));
    fprintf('  coherencia > 0.10      : %s\n', rep(hi));
    fprintf('  imagenes con dispersion > 30 deg: %d de %d\n', sum(dispersion_total(val)>30), sum(val));
    fprintf('  imagenes con dispersion < 5 deg : %d de %d\n', sum(dispersion_total(val)<5),  sum(val));

    % --- guardar CSV ---
    outDir = fileparts(outCSV);
    if ~isempty(outDir) && ~exist(outDir,'dir'), mkdir(outDir); end
    fid = fopen(outCSV,'w');
    hdr = 'imagen,coherencia';
    for j=1:nS, hdr = [hdr sprintf(',theta_sd%g', sd_list(j))]; end %#ok<AGROW>
    hdr = [hdr ',dispersion_total,salto_max_consec'];
    fprintf(fid,'%s\n',hdr);
    for k = 1:N
        fprintf(fid,'%s,%.4f', nombres{k}, coh(k));
        for j=1:nS, fprintf(fid,',%.2f', ANG(k,j)); end
        fprintf(fid,',%.2f,%.2f\n', dispersion_total(k), salto_max_consec(k));
    end
    fclose(fid);
    fprintf('\nCSV guardado -> %s\n', outCSV);
    fprintf('Escalas de sigma_d barridas: %s  (sigma_i=%g)\n', mat2str(sd_list), sigma_i);
end


function [orient, coh] = orient_coh(BW2_closed, sigma_d, sigma_i)
    G_ori = imgaussfilt(double(BW2_closed), sigma_d);
    [Gx_o, Gy_o] = gradient(G_ori);          % MATLAB: [FX, FY] = [d/dx, d/dy]
    Jxx_m = imgaussfilt(Gx_o.^2,     sigma_i);
    Jyy_m = imgaussfilt(Gy_o.^2,     sigma_i);
    Jxy_m = imgaussfilt(Gx_o.*Gy_o,  sigma_i);
    roi = BW2_closed;
    Sxx=sum(Jxx_m(roi)); Syy=sum(Jyy_m(roi)); Sxy=sum(Jxy_m(roi));
    if sum(roi(:))>10 && (Sxx+Syy)>0
        orient = mod(0.5*atan2d(2*Sxy, Sxx-Syy)+90, 180);
        l1=0.5*(Sxx+Syy)+0.5*sqrt((Sxx-Syy)^2+4*Sxy^2);
        l2=0.5*(Sxx+Syy)-0.5*sqrt((Sxx-Syy)^2+4*Sxy^2);
        coh=(l1-l2)/(l1+l2);
    else, orient=NaN; coh=NaN; end
end


function BW2_closed = procesar_mascara(fp, sens, pix_minimos)
    Full = IBWread(fp);
    Elec_Raw = rot90(double(Full.y(:,:,5)));
    Topo     = rot90(double(Full.y(:,:,1)));
    if ~isequal(size(Elec_Raw), size(Topo)), Elec_Raw = imresize(Elec_Raw, size(Topo)); end
    En=(Elec_Raw-median(Elec_Raw(:)))/mad(Elec_Raw(:),1);
    Tn=(Topo-median(Topo(:)))/mad(Topo(:),1);
    [Gy,Gx]=gradient(Tn); X=[Tn(:),Gx(:),Gy(:),ones(numel(Tn),1)]; b=X\En(:);
    Ec=En-reshape(X*b,size(En));
    E1=Etapa1_SyP_Selectivo(Ec,[5 5],3); Es=line_strip_correction(E1);
    Ecl=Etapa1_SyP_Selectivo(Es,[5 1],2); Eseg=rescale_1_99(Ecl);
    th=multithresh(Eseg,6); BW1=bwareaopen(Eseg>=th(1),pix_minimos);
    Tr=adaptthresh(Eseg,sens,'NeighborhoodSize',[51 51],'Statistic','gaussian','ForegroundPolarity','bright');
    Tl=adaptthresh(Eseg,sens,'NeighborhoodSize',[21 21],'Statistic','gaussian','ForegroundPolarity','bright');
    BW2=bwareaopen(BW1 & imbinarize(Eseg,Tr) & imbinarize(Eseg,Tl),pix_minimos);
    if sum(BW2(:))/numel(BW2)<0.15
        Tf=adaptthresh(Eseg,0.55,'NeighborhoodSize',[21 21],'Statistic','gaussian','ForegroundPolarity','bright');
        BW2=bwareaopen(imbinarize(Eseg,Tf),50);
    end
    BW2_closed=imclose(BW2,strel('disk',3));
end

function I_out=line_strip_correction(I_in)
    [r,~]=size(I_in); I_out=zeros(size(I_in));
    for i=1:r
        row=I_in(i,:); sigma=mad(row,1); dyn=prctile(row,95)-prctile(row,5);
        p=max(25,min(45,40-20*sigma/dyn)); cutoff=prctile(row,p);
        bg=row(row<=cutoff); if isempty(bg), o=median(row); else, o=median(bg); end
        I_out(i,:)=row-o;
    end
end
function I_Out=Etapa1_SyP_Selectivo(I_In,ks,ns)
    F=medfilt2(I_In,ks); R=abs(I_In-F); s=median(R(:))/0.6745; M=R>(ns*s);
    I_Out=I_In; I_Out(M)=F(M);
end
function Img=rescale_1_99(D)
    li=prctile(D(:),1); ls=prctile(D(:),99);
    if ls==li, Img=zeros(size(D)); return; end
    Img=(D-li)/(ls-li); Img(Img<0)=0; Img(Img>1)=1;
end
