function barrido_poda()
% BARRIDO_PODA  Barrido de la poda de endpoints del esqueleto (bwmorph spur).
% Paralelo a §4.2.1 (radio del cierre) y §4.2.2 (ventana RLOESS): valida la
% elección de 5 iteraciones midiendo su efecto sobre los DOS descriptores que
% dependen del esqueleto: tortuosidad media y longitud de red.
%
% Reproduce el pipeline hasta BW2_closed (validado, SANITY=0 en orientación),
% calcula el esqueleto base UNA vez por imagen y le aplica cada nivel de poda.
% La tortuosidad y la longitud usan el MISMO código que Main.m.
%
% Salidas:
%   - barrido_poda.csv : una fila por (imagen x valor de poda) = 81 x 5
%   - consola: tabla agregada (medias sobre las 81 imagenes), una fila por
%     valor de poda, + cambio relativo respecto a poda=5 (para ver el codo)
%     + SANITY automatico en poda=5 contra descriptores.csv.

clc;

% ------------------- CONFIG (rutas como en Main.m) -------------------
rutas = rutas_tesis();   % rutas relativas al repositorio (codigo/utils)
inputFolder = rutas.crudos;
outputCSV   = fullfile(rutas.resultados, 'barrido_poda.csv');
refCSV      = fullfile(rutas.resultados, 'descriptores.csv');

sensibilidad = 0.55;
pix_minimos  = 50;
nm_por_pixel = 60000/1024;
nm_a_um      = 1e-3;
Lmin_arco    = 15;                 % igual que Main.m
PODA_VALS    = [0 3 5 7 10];       % iteraciones de poda a barrer (5 = actual)

ibwFiles = dir(fullfile(inputFolder,'*.ibw'));
outDir = fileparts(outputCSV); if ~exist(outDir,'dir'), mkdir(outDir); end
setenv('LC_NUMERIC','C')
fid = fopen(outputCSV,'w');
fprintf(fid,['imagen,voltaje_V,frecuencia_Hz,poda,'...
    'tortuosidad_media,network_length_um,skel_px,n_extremos\n']);

nP = numel(PODA_VALS);
A_tort=cell(1,nP); A_len=cell(1,nP); A_px=cell(1,nP); A_ext=cell(1,nP);
for j=1:nP, A_tort{j}=[]; A_len{j}=[]; A_px{j}=[]; A_ext{j}=[]; end
img5={}; tort5=[]; len5=[];     % para el sanity en poda=5

for k = 1:numel(ibwFiles)
    filename = ibwFiles(k).name;
    try
        BW2_closed   = pipeline_mascara(fullfile(inputFolder,filename), sensibilidad, pix_minimos);
        [v,f]        = fab(filename);
        BW_skel_base = bwskel(BW2_closed);          % esqueleto SIN podar

        for j = 1:nP
            p = PODA_VALS(j);
            if p == 0
                BWs = BW_skel_base;
            else
                BWs = bwmorph(BW_skel_base, 'spur', p);   % p iteraciones de poda
            end
            [tort,len,px,next] = metricas_esqueleto(BWs, nm_por_pixel, nm_a_um, Lmin_arco);

            fprintf(fid,'%s,%g,%g,%d,%.6f,%.6f,%d,%d\n', filename, v, f, p, tort, len, px, next);
            A_tort{j}(end+1)=tort; A_len{j}(end+1)=len; A_px{j}(end+1)=px; A_ext{j}(end+1)=next;
            if p==5, img5{end+1}=filename; tort5(end+1)=tort; len5(end+1)=len; end %#ok<AGROW>
        end
        fprintf('Procesado %d/%d: %s\n', k, numel(ibwFiles), filename);
    catch ME
        fprintf('Error en %s: %s\n', filename, ME.message);
    end
end
fclose(fid);

% ===================== TABLA AGREGADA (medias) =====================
fprintf('\n============== BARRIDO DE PODA (medias sobre %d imagenes) ==============\n', numel(A_tort{1}));
fprintf('%5s | %12s | %14s | %10s | %10s\n','poda','tortuosidad','network[um]','skel[px]','n_extremos');
fprintf('%s\n', repmat('-',1,62));
for j = 1:nP
    fprintf('%5d | %12.4f | %14.1f | %10.0f | %10.1f\n', PODA_VALS(j), ...
        mean(A_tort{j},'omitnan'), mean(A_len{j},'omitnan'), mean(A_px{j}), mean(A_ext{j}));
end

i5 = find(PODA_VALS==5,1);
fprintf('\nCambio relativo respecto a poda=5 (actual) -> para ver el codo:\n');
for j = 1:nP
    dt = 100*(mean(A_tort{j},'omitnan')/mean(A_tort{i5},'omitnan') - 1);
    dl = 100*(mean(A_len{j},'omitnan')/mean(A_len{i5},'omitnan') - 1);
    fprintf('   poda=%2d:  tortuosidad %+6.1f%%  |  longitud %+6.1f%%\n', PODA_VALS(j), dt, dl);
end

% ===================== SANITY: poda=5 vs descriptores.csv =====================
if exist(refCSV,'file')
    try
        T = readtable(refCSV);
        dt = nan(1,numel(img5));  dl = nan(1,numel(img5));
        for i = 1:numel(img5)
            r = strcmp(string(T.imagen), img5{i});
            if any(r)
                a=tort5(i); b=T.tortuosidad_media(find(r,1)); if isfinite(a)&&isfinite(b), dt(i)=abs(a-b); end
                a=len5(i);  b=T.network_length_um(find(r,1)); if isfinite(a)&&isfinite(b), dl(i)=abs(a-b); end
            end
        end
        fprintf('\nSANITY poda=5 vs descriptores.csv:  max|dif tortuosidad|=%.4g  |  max|dif longitud|=%.4g um\n', max(dt), max(dl));
        fprintf('   (deben ser ~0: confirman que el esqueleto y los dos descriptores se reproducen)\n');
    catch ME2
        fprintf('SANITY: no se pudo comparar con %s (%s)\n', refCSV, ME2.message);
    end
else
    fprintf('\nSANITY: %s no encontrado; compara a mano la fila poda=5.\n', refCSV);
end

fprintf('\nCSV escrito -> %s\n', outputCSV);
end


% =========================== SUBFUNCIONES ===========================
function [tort_media, len_um, skel_px, n_endpoints] = metricas_esqueleto(BW_skel, nm_px, nm_a_um, Lmin_arco)
    skel_px     = nnz(BW_skel);
    n_endpoints = nnz(bwmorph(BW_skel,'endpoints'));

    % --- tortuosidad: diametro geodesico / cuerda (IDENTICO a Main.m) ---
    CC = bwconncomp(BW_skel, 8);
    tort = [];
    for ii = 1:CC.NumObjects
        pixels = CC.PixelIdxList{ii};
        if numel(pixels) < 8, continue; end
        sc = false(size(BW_skel)); sc(pixels) = true;
        [ye, xe] = find(bwmorph(sc,'endpoints'));
        if numel(ye) < 2, continue; end
        lin = sub2ind(size(sc), ye, xe);
        D1  = bwdistgeodesic(sc, xe(1), ye(1), 'quasi-euclidean');
        [~,a]      = max(D1(lin));
        DA  = bwdistgeodesic(sc, xe(a), ye(a), 'quasi-euclidean');
        [larco,b]  = max(DA(lin));
        dext = hypot(ye(a)-ye(b), xe(a)-xe(b));
        if isfinite(larco) && larco >= Lmin_arco && dext > 0
            tort(end+1) = larco/dext; %#ok<AGROW>
        end
    end
    if isempty(tort), tort_media = NaN; else, tort_media = mean(tort); end

    % --- longitud de red: ortogonales peso 1, diagonales peso sqrt(2) (IDENTICO a Main.m) ---
    H = BW_skel(:,1:end-1) & BW_skel(:,2:end);
    V = BW_skel(1:end-1,:) & BW_skel(2:end,:);
    n_orto = nnz(H) + nnz(V);
    D1a = BW_skel(1:end-1,1:end-1) & BW_skel(2:end,2:end) & ~BW_skel(1:end-1,2:end)  & ~BW_skel(2:end,1:end-1);
    D2a = BW_skel(1:end-1,2:end)   & BW_skel(2:end,1:end-1) & ~BW_skel(1:end-1,1:end-1) & ~BW_skel(2:end,2:end);
    n_diag = nnz(D1a) + nnz(D2a);
    len_um = (n_orto + sqrt(2)*n_diag) * nm_px * nm_a_um;
end

function BW2_closed = pipeline_mascara(path, sensibilidad, pix_minimos)
    Full = IBWread(path);
    Elec_Raw = rot90(double(Full.y(:,:,5)));
    Topo     = rot90(double(Full.y(:,:,1)));
    if ~isequal(size(Elec_Raw), size(Topo)), Elec_Raw = imresize(Elec_Raw, size(Topo)); end
    Elec_norm = (Elec_Raw - median(Elec_Raw(:))) / mad(Elec_Raw(:),1);
    Topo_norm = (Topo     - median(Topo(:)))     / mad(Topo(:),1);
    [Gy,Gx] = gradient(Topo_norm);
    X = [Topo_norm(:), Gx(:), Gy(:), ones(numel(Topo_norm),1)];
    beta = X \ Elec_norm(:);
    Elec_fit = reshape(X*beta, size(Elec_norm));
    Elec_corr = Elec_norm - Elec_fit;
    Elec_c1  = SyP(Elec_corr, [5 5], 3);
    Elec_str = line_strip(Elec_c1);
    Elec_cln = SyP(Elec_str, [5 1], 2);
    Eseg     = resc199(Elec_cln);
    thr = multithresh(Eseg, 6);
    BW1 = bwareaopen(Eseg >= thr(1), pix_minimos);
    Tr  = adaptthresh(Eseg, sensibilidad, 'NeighborhoodSize',[51 51], 'Statistic','gaussian','ForegroundPolarity','bright');
    BWr = imbinarize(Eseg, Tr);
    Tl  = adaptthresh(Eseg, sensibilidad, 'NeighborhoodSize',[21 21], 'Statistic','gaussian','ForegroundPolarity','bright');
    BWl = imbinarize(Eseg, Tl);
    BW2 = bwareaopen(BW1 & BWr & BWl, pix_minimos);
    if sum(BW2(:))/numel(BW2) < 0.15
        Tf  = adaptthresh(Eseg, 0.55, 'NeighborhoodSize',[21 21], 'Statistic','gaussian','ForegroundPolarity','bright');
        BW2 = bwareaopen(imbinarize(Eseg, Tf), 50);
    end
    BW2_closed = imclose(BW2, strel('disk', 3));
end

function I_Out = SyP(I_In, kernel_size, n_sigmas)
    Fondo = medfilt2(I_In, kernel_size);
    R     = abs(I_In - Fondo);
    sig   = median(R(:)) / 0.6745;
    M     = R > (n_sigmas * sig);
    I_Out = I_In;  I_Out(M) = Fondo(M);
end

function I_out = line_strip(I_in)
    [r,~] = size(I_in);  I_out = zeros(size(I_in));
    for i = 1:r
        row = I_in(i,:);  s = mad(row,1);
        dyn = prctile(row,95) - prctile(row,5);  ratio = s/dyn;
        p   = max(25, min(45, 40 - 20*ratio));  cutoff = prctile(row, p);
        bg  = row(row <= cutoff);
        if isempty(bg), off = median(row); else, off = median(bg); end
        I_out(i,:) = row - off;
    end
end

function Img = resc199(Data)
    li = prctile(Data(:),1);  ls = prctile(Data(:),99);
    if ls == li, Img = zeros(size(Data)); return; end
    Img = (Data - li)/(ls - li);  Img(Img<0)=0;  Img(Img>1)=1;
end

function [v,f] = fab(filename)
    v = NaN; f = NaN;
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
end
