function [voltaje_V, frecuencia_Hz, replica, posicion] = parsear_fabricacion_ibw(nombre_archivo)
% PARSEAR_FABRICACION_IBW  Voltaje, frecuencia, réplica y posición a partir del
% nombre '[0-2][abc]-[1-9].ibw' (0/1/2 = 5/10/15 V; a/b/c = 10 Hz/1 kHz/100 kHz).
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
