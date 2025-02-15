%%%%%%%%%%%%%% CONSTRUCCIÓN DE ESCALOGRAMAS %%%%%%%%%%%%%%%%%
clear 
clc
close all
 
% Carpeta de entrada
folder_path = ' Direccion de folder de clase con sus muestras';  % Modificar manualmente clase por clase para la generacion de escalogramas
file_pattern = fullfile(folder_path, '*.wav'); 
files = dir(file_pattern);
nf = length(files);
 
% Carpetas de salida
folder_path_1 = 'Output_Escalograma\Morlet\engine_idiling'; % Carpeta de salida de imagenes tipo Morlet
folder_path_2 = 'Output_Escalograma\Bump\engine_idiling';   % Carpeta de salida de imagenes tipo Bump

 
% Crear una figura para las imágenes
hFig = figure('Position', [100, 100, 224, 224], 'Visible', 'off');
 
% Generación de escalogramas
for k = 1:nf
    file_name = fullfile(folder_path, files(k).name);
    [audioIn, fs] = audioread(file_name);
    nombre = files(k).name(1:end-4); % Quitar el .wav del nombre
    nombre = strcat(nombre, '.png');
    % Convertir a mono si es estéreo
    if size(audioIn, 2) > 1
        audioIn = mean(audioIn, 2); 
    end
 
    % Banco de filtros para wavelet amor (similar a Morlet)
    fb_amor = cwtfilterbank('SignalLength', numel(audioIn), ...
                            'SamplingFrequency', fs, ...
                            'Wavelet', 'amor');
    % Calcular el escalograma
    [cfs, freq] = wt(fb_amor, audioIn);
 
    % Crear la gráfica con `surf` para ajustar las visualizaciones
    surf(1:size(cfs,2), freq, abs(cfs), 'EdgeColor', 'none');
    colormap('viridis');
    view(0, 90); % Vista desde arriba para una visualización 2D
    axis tight;
 
    % Ajustes de ejes
    set(gca, 'Visible', 'off'); 
    colorbar('off'); 
    ax = gca; 
    ax.Position = [0 0 1 1];
 
    % Guardar el escalograma sin ejes
    file_name = fullfile(folder_path_1, nombre);
    saveas(hFig, file_name);
 
    % Banco de filtros para wavelet bump
    fb_bump = cwtfilterbank('SignalLength', numel(audioIn), ...
                            'SamplingFrequency', fs, ...
                            'Wavelet', 'bump');
    % Calcular el escalograma para bump
    [cfs_bump, freq_bump] = wt(fb_bump, audioIn);
    surf(1:size(cfs_bump,2), freq_bump, abs(cfs_bump), 'EdgeColor', 'none');
    colormap('viridis');
    view(0, 90);
    axis tight;

    % Ajustes de ejes y guardado
    set(gca, 'Visible', 'off'); 
    colorbar('off');
    ax = gca;
    ax.Position = [0 0 1 1];
    % Guardar el escalograma sin ejes
    file_name = fullfile(folder_path_2, nombre);
    saveas(hFig, file_name);
end
 
% Cierra la figura al finalizar
close(hFig);
