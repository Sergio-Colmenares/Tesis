function generar_mosaicos_2b()
% =========================================================================
% generar_mosaicos_2b.m
% Genera 6 mosaicos 3x3 del set 2b (uno por familia de descriptores) para
% reforzar visualmente cada subseccion de §3.2.
%
% Arquitectura: procesa las 9 imagenes UNA vez, luego genera cada mosaico
% en su propia figura (invisible, renderer painters), la exporta y la cierra
% antes de pasar a la siguiente. Asi se evita el "Graphics timeout" que
% ocurre al tener varias figuras grandes vivas a la vez.
%
% Salida: 6 PDF vectoriales en la carpeta Mosaicos.
% Uso: escribir   generar_mosaicos_2b   en la ventana de comandos.
% =========================================================================

    clc;

    % -------------------- RUTAS (ya configuradas) --------------------
    rutas = rutas_tesis();   % rutas relativas al repositorio (codigo/utils)
    inputFolder     = rutas.crudos;
    colormapMATpath = rutas.colormap;
    outDir          = fullfile(rutas.resultados, 'Mosaicos');

    % -------------------- Parametros del pipeline --------------------
    sensibilidad = 0.55;
    pix_minimos  = 50;
    ventana_grad = 50;

    % -------------------- Colormap (igual que Figs 4.1-4.5) ----------
    if exist(colormapMATpath,'file')
        S = load(colormapMATpath); nm = fieldnames(S); myColormap = S.(nm{1});
    else
        myColormap = parula(256);
        warning('No se encontro python_colormaps.mat; se usa parula.');
    end

    if ~exist(outDir,'dir'), mkdir(outDir); end

    files = dir(fullfile(inputFolder,'2b-*.ibw'));
    if isempty(files)
        error('No se encontraron archivos 2b-*.ibw en %s', inputFolder);
    end
    fprintf('Encontrados %d archivos 2b en %s\n', numel(files), inputFolder);

    fam = {'espacial','intensidad','forma','orientacion','conectividad','perfil'};
    tit = {'Muestreo de cuerdas (CNTD/CNTA/CNTS)', ...
           'Señal 2\omega enmascarada (intensidad)', ...
           'Componentes y elipses (forma)', ...
           'Orientación por segmento y dominante', ...
           'Clúster mayor y esqueleto (conectividad)', ...
           'Perfil vertical y ajuste lineal'};

    % ============ 1) PROCESAR LAS 9 IMAGENES UNA SOLA VEZ ============
    Pall = cell(1,9);
    for k = 1:numel(files)
        fn = files(k).name;
        [~,~,replica,posicion] = parsear_fabricacion(fn);
        if isnan(replica) || isnan(posicion), continue; end
        idx = (replica-1)*3 + posicion;          % replica=fila, posicion=columna
        try
            P = procesar_2b(fullfile(inputFolder,fn), sensibilidad, pix_minimos, ventana_grad);
            Pall{idx} = rmfield(P, {'Eseg','BW2'});   % libera campos no usados en los paneles
        catch ME
            fprintf('  ERROR procesando %s: %s\n', fn, ME.message);
        end
        fprintf('Procesada %s (%d/9)\n', fn, idx);
    end

    % Escala de color comun para el panel de intensidad
    vv   = cellfun(@(P) P.EB(:), Pall(~cellfun(@isempty,Pall)), 'UniformOutput', false);
    allv = cat(1, vv{:}) * 1e12;
    cl   = [prctile(allv,1), prctile(allv,99)];
    if ~(isfinite(cl(1)) && isfinite(cl(2)) && cl(2) > cl(1))
        cl = [min(allv), max(allv)];
    end

    % ===== 2) UN MOSAICO A LA VEZ: crear, dibujar, exportar, cerrar =====
    fprintf('\nGuardando mosaicos en: %s\n', outDir);
    for f = 1:6
        Fig = figure('Color','w','Position',[40 40 980 980], ...
                     'Visible','off');   % invisible (sin forzar renderer: el de por defecto es mas rapido con muchas lineas)
        T = tiledlayout(Fig,3,3,'TileSpacing','compact','Padding','compact');
        title(T, tit{f}, 'FontWeight','bold');
        axI = [];
        for idx = 1:9
            if isempty(Pall{idx}), continue; end
            r = floor((idx-1)/3)+1; p = mod(idx-1,3)+1;
            ax = nexttile(T, idx);
            dibujar_panel(ax, f, Pall{idx}, r, p, myColormap, cl);
            rc_labels(ax, r, p);
            if f == 2, axI = ax; end
        end
        if f == 2 && ~isempty(axI)
            cb = colorbar(axI); cb.Label.String = 'pm';
        end

        outFile = fullfile(outDir, ['mosaico_' fam{f} '.pdf']);
        ok = false;
        try
            exportgraphics(Fig, outFile, 'ContentType','vector', 'Resolution',300);
            ok = (exist(outFile,'file') == 2);
        catch ME1
            fprintf('  exportgraphics fallo (%s); intento con print...\n', ME1.message);
            try
                print(Fig, fullfile(outDir,['mosaico_' fam{f}]), '-dpdf','-painters','-r300');
                ok = (exist(outFile,'file') == 2);
            catch ME2
                fprintf('  print tambien fallo: %s\n', ME2.message);
            end
        end
        if ok
            fprintf('  OK  -> mosaico_%s.pdf\n', fam{f});
        else
            fprintf('  *** NO se genero mosaico_%s.pdf ***\n', fam{f});
        end
        close(Fig);   % libera la figura antes de la siguiente
    end
    fprintf('\nListo.\n');
end


% =========================================================================
% DIBUJO DE UN PANEL SEGUN LA FAMILIA
% =========================================================================
function dibujar_panel(ax, f, P, r, p, myColormap, cl)
    switch f
        case 1  % ESPACIAL: pinta las 100 filas muestreadas EN el raster
                % (cada linea ES una fila de la imagen -> exactamente 1 px de alto,
                %  imposible que sea mas gruesa; verde=CNT (CNTA), amarillo=hueco (CNTD))
            BW = P.BWc; [H,W] = size(BW);
            baseG = double(BW);                      % mascara real: CNT=blanco(1), fondo=negro(0)
            Rc = baseG; Gc = baseG; Bc = baseG;
            rng(42);
            for ll = 1:100
                fy  = randi(H);
                cnt = BW(fy,:) == 1;                 % CNT en esa fila
                gap = ~cnt;                          % hueco de polimero
                Rc(fy,cnt)=0;   Gc(fy,cnt)=0.9; Bc(fy,cnt)=0.2;   % verde
                Rc(fy,gap)=1;   Gc(fy,gap)=1;   Bc(fy,gap)=0;     % amarillo
            end
            imagesc(ax, cat(3,Rc,Gc,Bc)); axis(ax,'image','off');

        case 2  % INTENSIDAD: señal E_B en pm, escala comun
            imagesc(ax, P.EB*1e12); caxis(ax, cl);
            colormap(ax, myColormap); axis(ax,'image','off');

        case 3  % FORMA: componentes coloreados + elipses
            L = labelmatrix(bwconncomp(P.BWc));
            imagesc(ax, label2rgb(L,'jet','k','shuffle')); axis(ax,'image','off'); hold(ax,'on');
            pp = regionprops(P.BWc,'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area');
            if ~isempty(pp)
                [~,ord] = sort([pp.Area],'descend'); t = linspace(0,2*pi,40);
                for q = ord(1:min(10,numel(ord)))
                    a = pp(q).MajorAxisLength/2; b = pp(q).MinorAxisLength/2;
                    th = -deg2rad(pp(q).Orientation);
                    xx = pp(q).Centroid(1) + a*cos(t)*cos(th) - b*sin(t)*sin(th);
                    yy = pp(q).Centroid(2) + a*cos(t)*sin(th) + b*sin(t)*cos(th);
                    plot(ax,xx,yy,'w-','LineWidth',0.6);
                end
            end

        case 4  % ORIENTACION: barra por segmento (amarillo) + barra global (rojo)
            imagesc(ax,P.G_ori); colormap(ax,gray); axis(ax,'image','off'); hold(ax,'on');
            for q = 1:numel(P.seg_ang)
                aa = deg2rad(P.seg_ang(q)); Ls = 0.45*P.seg_len(q);  % media extension del segmento
                plot(ax, [P.seg_cx(q)-Ls*cos(aa) P.seg_cx(q)+Ls*cos(aa)], ...
                         [P.seg_cy(q)-Ls*sin(aa) P.seg_cy(q)+Ls*sin(aa)], ...
                         '-','Color',[1 1 0],'LineWidth',1.1);
            end
            [hh, ww] = size(P.BWc); cx = ww/2; cy = hh/2; Ll = 0.45*min(hh,ww);
            ang = deg2rad(P.orient); dx = Ll*cos(ang); dy = Ll*sin(ang);
            plot(ax, [cx-dx cx+dx], [cy-dy cy+dy], '-', 'Color',[1 0.2 0.2], 'LineWidth',2.5);

        case 5  % CONECTIVIDAD: cluster mayor (rojo) + esqueleto (verde)
            rgb = repmat(double(P.BWc)*0.55,[1 1 3]);
            R = rgb(:,:,1); R(P.mayor) = 1; rgb(:,:,1) = R;
            imagesc(ax,rgb); axis(ax,'image','off'); hold(ax,'on');
            [ys,xs] = find(P.sk); plot(ax,xs,ys,'.','Color',[0 1 0],'MarkerSize',1);

        case 6  % PERFIL: vertical (fila en Y invertido), intensidad en pm
            fil = (1:numel(P.pB))';
            plot(ax, P.pB*1e12, fil, 'b-'); hold(ax,'on');
            plot(ax, P.pfit*1e12, fil, 'r--', 'LineWidth',1);
            set(ax,'YDir','reverse'); ylim(ax,[1 numel(P.pB)]);
            set(ax,'YTickLabel',[]); grid(ax,'on'); ax.FontSize = 7;
            if r == 3, xlabel(ax, 'pm', 'FontSize',9); end
            if p == 1, ylabel(ax, 'fila [px]', 'FontSize',8); end
    end
end


% =========================================================================
% FUNCIONES LOCALES
% =========================================================================

function rc_labels(ax, r, p)
% Etiquetas de borde: P (columna) sobre la fila superior y R (fila) a la izquierda.
    if r == 1
        text(ax, 0.5, 1.05, sprintf('P%d', p), 'Units','normalized', ...
             'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
             'FontWeight','bold', 'FontSize',11, 'Clipping','off');
    end
    if p == 1
        text(ax, -0.10, 0.5, sprintf('R%d', r), 'Units','normalized', ...
             'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
             'Rotation',90, 'FontWeight','bold', 'FontSize',11, 'Clipping','off');
    end
end

function P = procesar_2b(fp, sens, pix_minimos, vent)
% Reproduce el pipeline sobre una imagen y devuelve lo necesario para dibujar.
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
    BWc = imclose(BW2, strel('disk',3));

    EcB = Elec_Raw - Efit .* mad(Elec_Raw(:),1);
    Esy = Etapa1_SyP_Selectivo(EcB, [5 5], 3);
    pV  = median(Esy,2);
    tend = smoothdata(pV,'rloess',vent);
    EB  = Esy - (pV - tend);

    sk = bwmorph(bwskel(BWc),'spur',5);   % esqueleto (solo para el panel de conectividad)

    % --- ORIENTACION: tensor de estructura sobre la mascara en grises ---
    sigma_d = 2; sigma_i = 8;
    G_ori = imgaussfilt(double(BWc), sigma_d);
    [Gx_o, Gy_o] = gradient(G_ori);                 % MATLAB: [FX, FY] = [d/dx, d/dy]
    Jxx_m = imgaussfilt(Gx_o.^2,    sigma_i);
    Jyy_m = imgaussfilt(Gy_o.^2,    sigma_i);
    Jxy_m = imgaussfilt(Gx_o.*Gy_o, sigma_i);
    roi = BWc;
    Sxx = sum(Jxx_m(roi)); Syy = sum(Jyy_m(roi)); Sxy = sum(Jxy_m(roi));
    orient = mod(0.5*atan2d(2*Sxy, Sxx-Syy) + 90, 180);

    % --- orientacion por segmento (cada componente conexo) ---
    Lc = bwlabel(BWc);
    st = regionprops(Lc,'Area','Centroid','PixelIdxList','MajorAxisLength');
    seg_cx = []; seg_cy = []; seg_ang = []; seg_len = [];
    min_area_seg = 150;   % area minima (px) para dibujar la barra de un segmento
    for kk = 1:numel(st)
        if st(kk).Area < min_area_seg, continue; end
        ix = st(kk).PixelIdxList;
        sx = sum(Jxx_m(ix)); sy = sum(Jyy_m(ix)); sxyk = sum(Jxy_m(ix));
        if (sx+sy) <= 0, continue; end
        seg_cx(end+1)  = st(kk).Centroid(1);                       %#ok<AGROW>
        seg_cy(end+1)  = st(kk).Centroid(2);                       %#ok<AGROW>
        seg_ang(end+1) = mod(0.5*atan2d(2*sxyk, sx-sy) + 90, 180); %#ok<AGROW>
        seg_len(end+1) = st(kk).MajorAxisLength;                   %#ok<AGROW>
    end

    cc = bwconncomp(BWc);
    sz = cellfun(@numel, cc.PixelIdxList);
    [~,im] = max(sz);
    mayor = false(size(BWc)); mayor(cc.PixelIdxList{im}) = true;

    pB = median(EB,2); xf = (1:numel(pB))'; pf = polyfit(xf,pB,1);

    P = struct('Eseg',Eseg,'BW2',BW2,'BWc',BWc,'EB',EB,'sk',sk, ...
               'G_ori',G_ori,'Gx_o',Gx_o,'Gy_o',Gy_o,'orient',orient, ...
               'seg_cx',seg_cx,'seg_cy',seg_cy,'seg_ang',seg_ang,'seg_len',seg_len, ...
               'percol',max(sz)/sum(sz),'nfrag',cc.NumObjects, ...
               'mayor',mayor,'pB',pB,'pfit',polyval(pf,xf));
end

function [voltaje_V, frecuencia_Hz, replica, posicion] = parsear_fabricacion(filename)
    voltaje_V = NaN; frecuencia_Hz = NaN; replica = NaN; posicion = NaN;
    [~, nombre, ~] = fileparts(filename);
    tok = regexp(nombre, '^([0-2])([abc])-([1-9])$', 'tokens');
    if isempty(tok)
        warning('Nombre de archivo no coincide con el formato esperado: %s', filename);
        return;
    end
    switch tok{1}{1}
        case '0', voltaje_V = 5;
        case '1', voltaje_V = 10;
        case '2', voltaje_V = 15;
    end
    switch tok{1}{2}
        case 'a', frecuencia_Hz = 10;
        case 'b', frecuencia_Hz = 1000;
        case 'c', frecuencia_Hz = 100000;
    end
    img_num  = str2double(tok{1}{3});
    replica  = ceil(img_num / 3);
    posicion = mod(img_num - 1, 3) + 1;
end

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
        if isempty(bg_pix)
            offset = median(row);
        else
            offset = median(bg_pix);
        end
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
    if lim_sup == lim_inf
        Img_Vis = zeros(size(Data));
        return;
    end
    Img_Vis = (Data - lim_inf) / (lim_sup - lim_inf);
    Img_Vis(Img_Vis < 0) = 0;
    Img_Vis(Img_Vis > 1) = 1;
end
