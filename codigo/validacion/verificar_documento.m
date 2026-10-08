function verificar_documento()
% =========================================================================
% verificar_documento.m
%
% Verifica los valores reportados en el documento contra los CSVs
% definitivos. Solo imprime un resumen en consola: [OK] o [FAIL] por valor.
% No genera archivos.
%
% Tolerancia: 1% relativa o 0.005 absoluta, lo que sea más amplio.
% =========================================================================

clear; clc;
rutas = rutas_tesis();   % rutas relativas al repositorio (codigo/utils)
csvDir = rutas.resultados;

pre = readtable(fullfile(csvDir,'preprocesamiento55.csv'));
bar = readtable(fullfile(csvDir,'barrido_binarizacion55.csv'));
rad = readtable(fullfile(csvDir,'barrido_radio_cierre55.csv'));
rl  = readtable(fullfile(csvDir,'barrido_rloess.csv'));
desc= readtable(fullfile(csvDir,'descriptores.csv'));

% Pipeline mask (sens=0.55, pmin=50, Otsu=6, vR=51, vL=21, ufb=0.15)
m = bar.sensibilidad==0.55 & bar.pix_minimos==50 & bar.otsu_k==6 ...
  & bar.ventana_regional==51 & bar.ventana_local==21 & bar.umbral_fallback==0.15;
sub = bar(m,:);
bar_ufb = bar(bar.umbral_fallback==0.15,:);

global tot fail
tot=0; fail=0;

%% ===== TABLA CROSSTALK =====
section('Tabla crosstalk_2b');
img = {'2b-1','2b-2','2b-3','2b-4','2b-5','2b-6','2b-7','2b-8','2b-9'};
val = [0.0522,0.0040,-0.0121,0.0212,0.1230,-0.0062,0.0331,-0.1085,-0.0226];
for i=1:9
    check(img{i}, val(i), valOf(pre,[img{i} '.ibw'],'corr_pre_T'));
end
s = pre.corr_pre_T(startsWith(pre.imagen,'2b-'));
check('Set2b media',  0.0093,  mean(s));
check('Set2b std',    0.0623,  std(s));
g = pre.corr_pre_T;
check('Global media', -0.0285, mean(g));
check('Global std',   0.0750,  std(g));
check('Global min',  -0.2125,  min(g));
check('Global max',   0.1332,  max(g));
check('Global med',  -0.0134,  median(g));

%% ===== TABLA IMPULSIVO =====
section('Tabla impulsivo_2b (SyP 5x5 %)');
val = [4.35,1.57,0.49,0.31,0.44,0.40,1.07,1.48,0.68];
for i=1:9
    check(img{i}, val(i), 100*valOf(pre,[img{i} '.ibw'],'pct_SyP1'));
end
check('Global media', 3.73,  100*mean(pre.pct_SyP1));
check('Global min',   0.24,  100*min(pre.pct_SyP1));
check('Global max',  47.32,  100*max(pre.pct_SyP1));

section('Tabla impulsivo_2b (Lineas 5x1 %)');
val = [16.62,20.82,17.30,27.25,16.66,37.12,17.39,16.54,35.04];
for i=1:9
    check(img{i}, val(i), 100*valOf(pre,[img{i} '.ibw'],'pct_SyP2'));
end
check('Global media',23.18, 100*mean(pre.pct_SyP2));
check('Global min',  14.26, 100*min(pre.pct_SyP2));
check('Global max',  46.44, 100*max(pre.pct_SyP2));

%% ===== TABLA ARTEFACTOS =====
section('Tabla artefactos_2b (pre)');
val = [2.5357,3.6080,1.5582,1.7520,0.4934,0.7136,0.8245,0.9550,0.3977];
for i=1:9
    check(img{i}, val(i), valOf(pre,[img{i} '.ibw'],'var_filas_pre'));
end
section('Tabla artefactos_2b (post)');
val = [0.5440,0.0833,0.0862,0.0316,0.0915,0.1753,0.3114,0.2137,0.2134];
for i=1:9
    check(img{i}, val(i), valOf(pre,[img{i} '.ibw'],'var_filas_post'));
end
check('Global pre media', 1.7284, mean(pre.var_filas_pre));
check('Global pre max',  16.3627, max(pre.var_filas_pre));
check('Global post media',0.1313, mean(pre.var_filas_post));
check('Global post max',  1.1876, max(pre.var_filas_post));

%% ===== TABLA bin_2b =====
section('Tabla bin_2b');
val = [0.2005,0.2120,0.2097,0.2089,0.2215,0.2103,0.2232,0.2156,0.2167];
for i=1:9
    check([img{i} ' cob_Me'], val(i), valOf(desc,[img{i} '.ibw'],'cobertura_total'));
end
check('Global cob_Me media', 0.2202, mean(desc.cobertura_total));
check('Global cob_Me std',   0.0155, std(desc.cobertura_total));
check('Global cob_Me min',   0.1811, min(desc.cobertura_total));
check('Global cob_Me max',   0.2749, max(desc.cobertura_total));
check('Global Nc_Me media',  180.6,  mean(sub.islas_FINAL));
check('Global Nc_Me max',    396,    max(sub.islas_FINAL));

%% ===== VALIDACIÓN PARÁMETROS =====
section('Validación de parámetros');
PIPE_S=0.55; PIPE_PM=50; PIPE_O=6; PIPE_VR=51; PIPE_VL=21;
ss = sweepBy(bar_ufb,'sensibilidad',PIPE_S,PIPE_PM,PIPE_O,PIPE_VR,PIPE_VL);
check('sens=0.3 cob',  11.51, 100*ss.cov(ss.val==0.3));
check('sens=0.8 cob',  45.18, 100*ss.cov(ss.val==0.8));
check('sens=0.3 Nc',   254,   ss.Nc(ss.val==0.3));
check('sens=0.4 Nc',   274,   ss.Nc(ss.val==0.4));
check('sens=0.8 Nc',   65,    ss.Nc(ss.val==0.8));

pp = sweepBy(bar_ufb,'pix_minimos',PIPE_S,PIPE_PM,PIPE_O,PIPE_VR,PIPE_VL);
check('pmin: cob ~22.2%', 22.2,  100*mean(pp.cov));
check('pmin=10 Nc',       616,   pp.Nc(pp.val==10));
check('pmin=100 Nc',      146,   pp.Nc(pp.val==100));

vl = sweepBy(bar_ufb,'ventana_local',PIPE_S,PIPE_PM,PIPE_O,PIPE_VR,PIPE_VL);
check('vL=9  cob',  19.58, 100*vl.cov(vl.val==9));
check('vL=31 cob',  25.32, 100*vl.cov(vl.val==31));
check('vL=9  Nc',   483,   vl.Nc(vl.val==9));
check('vL=31 Nc',   145,   vl.Nc(vl.val==31));

vr = sweepBy(bar_ufb,'ventana_regional',PIPE_S,PIPE_PM,PIPE_O,PIPE_VR,PIPE_VL);
check('vR cob min', 20.16, 100*min(vr.cov));
check('vR cob max', 22.02, 100*max(vr.cov));

ot = sweepBy(bar_ufb,'otsu_k',PIPE_S,PIPE_PM,PIPE_O,PIPE_VR,PIPE_VL);
check('Otsu cob min', 21.57, 100*min(ot.cov));
check('Otsu cob max', 22.10, 100*max(ot.cov));

%% ===== ROBUSTEZ =====
section('Análisis de robustez');
[Q1,Med,~,FN_pipe,covPipe,NcPipe,FN_CV,n_configs] = robustness(bar_ufb,sub);
check('# configs',     1344,   n_configs);
check('Pipeline cob',  22.02,  100*covPipe);
check('Pipeline Nc',   180.6,  NcPipe);
check('Pipeline FN',   815,    FN_pipe);
check('Pipeline FN CV',0.2402, FN_CV);
check('Q1 FN',         582,    Q1);
check('Mediana FN',    1311,   Med);

%% ===== COMPARACIÓN MÉTODOS =====
section('Comparación de métodos');
methods = {'SoloLocal','GlobalLocal','TripleAND','FINAL'};
expected = [
    0.2720 0.0810 271.0 1110 988 0.2038;
    0.2562 0.1214 237.3 1215 916 0.1107;
    0.2190 0.0916 179.6 1348 818 0.1050;
    0.2202 0.0706 180.6 1350 815 0.1811;
];
totpx = 1024*1024;
for i=1:4
    c = sub.(['cov_' methods{i}]);
    n = sub.(['islas_' methods{i}]);
    tam = mean( (c*totpx) ./ max(n,1) );
    fn  = mean( n ./ max(c,eps) );
    check([methods{i} ' cob'],     expected(i,1), mean(c));
    check([methods{i} ' CV cob'],  expected(i,2), std(c)/mean(c));
    check([methods{i} ' Nc'],      expected(i,3), mean(n));
    check([methods{i} ' tam'],     expected(i,4), tam);
    check([methods{i} ' FN'],      expected(i,5), fn);
    check([methods{i} ' min cob'], expected(i,6), min(c));
end

%% ===== RADIO Y RLOESS =====
section('Radio (r=3) y RLOESS (v=50)');
r3 = rad(rad.radio_px==3,:);
check('r=3 cob_Mmor',  0.2597, mean(r3.cov_Mmor));
check('r=3 Nc_Mmor',   120.5,  mean(r3.Nc_Mmor));
check('r=3 delta_cov', 0.0395, mean(r3.delta_cov));
check('r=3 delta_Nc',  60.2,   mean(r3.delta_Nc));
check('r=3 skel_um',   835,    mean(r3.skel_um));
check('r=3 percol',    0.075,  mean(r3.percolacion));

v50 = rl(rl.ventana_filas==50,:);
check('v=50 rango_perfil', 43.02, median(v50.perfil_rango_pm));
check('v=50 rms_perfil',    5.98, median(v50.perfil_rms_pm));
check('v=50 rms_rayas',     2.71, median(v50.rms_rayas_pm));

%% ===== DESCRIPTORES =====
section('Descriptores');
% Espacial
check('CNTD mediana',   0.086,  median(desc.CNTD));
check('CNTD min',       0.068,  min(desc.CNTD));
check('CNTD max',       0.1324, max(desc.CNTD));    % CORREGIDO (era 0.128)
check('CNTA mediana',   0.281,  median(desc.CNTA));
check('CNTA Q1',        0.244,  quantile(desc.CNTA,0.25));
check('CNTA Q3',        0.305,  quantile(desc.CNTA,0.75));
check('CNTS mediana',   0.315,  median(desc.CNTS));
check('CNTS max',       0.846,  max(desc.CNTS));    % CORREGIDO (era 1.0)
% Intensidad
check('int_med mediana',495,    median(desc.intensidad_media_pm));
check('int_med min',    282,    min(desc.intensidad_media_pm));
check('int_med max',    1046,   max(desc.intensidad_media_pm));  % CORREGIDO
check('int_std mediana',24,     median(desc.intensidad_std_pm));
check('int_std max',    458,    max(desc.intensidad_std_pm));    % CORREGIDO
check('int_p90 mediana',537,    median(desc.intensidad_p90_pm));
check('int_p90 max',    1459,   max(desc.intensidad_p90_pm));    % CORREGIDO
check('grad mediana',   0.066,  median(desc.gradiente_medio_pm_nm));
check('grad max',       0.994,  max(desc.gradiente_medio_pm_nm)); % CORREGIDO
% Morfología
check('area_med mediana',7.64,  median(desc.area_media_um2));
check('area_med min',   3.728,  min(desc.area_media_um2));        % CORREGIDO
check('area_med max',  15.62,   max(desc.area_media_um2));
check('area_std mediana',9.46,  median(desc.area_std_um2));
check('area_std max',  72.86,   max(desc.area_std_um2));
check('elong mediana',  2.19,   median(desc.elongacion_media));
check('elong Q1',       2.11,   quantile(desc.elongacion_media,0.25));  % CORREGIDO (era 1.95)
check('elong Q3',       2.28,   quantile(desc.elongacion_media,0.75));
check('tort mediana',   1.66,   median(desc.tortuosidad_media));
check('tort min',       1.33,   min(desc.tortuosidad_media));
check('tort max',       2.31,   max(desc.tortuosidad_media));
% Orientación, conectividad, perfil
check('coher mediana',  0.063,  median(desc.coherencia));
check('coher max',      0.474,  max(desc.coherencia));
check('percol mediana', 0.062,  median(desc.indice_percolacion));
check('percol max',     0.513,  max(desc.indice_percolacion));
check('netlen mediana', 768,    median(desc.network_length_um));
check('netlen max',     1915,   max(desc.network_length_um));
check('rms_res mediana',5.98,   median(desc.perfil_residuo_rms_pm));
check('rms_res max',   30.84,   max(desc.perfil_residuo_rms_pm));
check('rango mediana', 43.02,   median(desc.perfil_rango_pm));
check('rango max',    225.76,   max(desc.perfil_rango_pm));

%% ===== RESUMEN =====
fprintf('\n========================================\n');
if fail==0
    fprintf('  RESULTADO: %d/%d OK  ✓ TODO CONSISTENTE\n', tot, tot);
else
    fprintf('  RESULTADO: %d/%d OK  ✗ %d DISCREPANCIAS\n', tot-fail, tot, fail);
end
fprintf('========================================\n');
end


% ========== Auxiliares ==========
function section(s)
    fprintf('\n--- %s ---\n', s);
end

function check(label, esperado, real)
    global tot fail
    tot = tot + 1;
    tol = max(0.005, abs(esperado)*0.01);
    ok  = abs(esperado-real) < tol;
    if ok
        fprintf('  [OK]   %-22s  esperado=%-10g real=%-10g\n', label, esperado, real);
    else
        fprintf('  [FAIL] %-22s  esperado=%-10g real=%-10g  *DIFF=%.4g\n', ...
                label, esperado, real, abs(esperado-real));
        fail = fail + 1;
    end
end

function v = valOf(T, imageName, colName)
    idx = strcmp(T.imagen, imageName);
    v = T.(colName)(idx);
end

function out = sweepBy(bar_ufb, paramName, PIPE_S,PIPE_PM,PIPE_O,PIPE_VR,PIPE_VL)
    PIPE = struct('sensibilidad',PIPE_S,'pix_minimos',PIPE_PM,'otsu_k',PIPE_O, ...
                  'ventana_regional',PIPE_VR,'ventana_local',PIPE_VL);
    f = fieldnames(PIPE);
    mask = true(height(bar_ufb),1);
    for i=1:numel(f)
        if ~strcmp(f{i},paramName)
            mask = mask & (bar_ufb.(f{i})==PIPE.(f{i}));
        end
    end
    s = bar_ufb(mask,:);
    vals = unique(s.(paramName));
    out.val = vals;
    out.cov = arrayfun(@(v) mean(s.cov_FINAL(s.(paramName)==v)), vals);
    out.Nc  = arrayfun(@(v) mean(s.islas_FINAL(s.(paramName)==v)), vals);
end

function [Q1,Med,Q3,FN_p,cov_p,Nc_p,FN_CV,n_configs] = robustness(bar_ufb,sub)
    key = {'sensibilidad','pix_minimos','otsu_k','ventana_regional','ventana_local'};
    [G,~] = findgroups(bar_ufb(:,key));
    n_configs = max(G);
    FN = bar_ufb.islas_FINAL ./ max(bar_ufb.cov_FINAL, eps);
    FN_byconf = splitapply(@mean, FN, G);
    Q1 = quantile(FN_byconf,0.25);
    Med= median(FN_byconf);
    Q3 = quantile(FN_byconf,0.75);
    cov_p = mean(sub.cov_FINAL);
    Nc_p  = mean(sub.islas_FINAL);
    fn_imgs = sub.islas_FINAL ./ max(sub.cov_FINAL,eps);
    FN_p = mean(fn_imgs);
    FN_CV= std(fn_imgs)/FN_p;
end
