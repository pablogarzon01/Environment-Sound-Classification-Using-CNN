%% CONSTRUCCION DE IMAGENES BASADAS EN STFT
clear,
clc,
close all

%% Enrutamiento de archivos
folder_path = 'Input';
if exist(folder_path, 'dir')
    disp('El directorio seleccionado existe');
else
    disp('El directorio seleccionado no existe');
end
% Lectura de archivo
files = dir(folder_path);
n_files = length(files);
fprintf('Numero de archivos: %d \n ' ,  n_files);

folder_output = 'C:\Users\pablo\OneDrive - unicauca.edu.co\Escritorio\TrabajoGrado\Bases_Datos\ProyectoMatlab\Script_matlab\Output';

%% Representacion Tiempo - Frecuencia (RTF)
%for k = 1:n_files
    k = 3;
    file_name = fullfile(folder_path, files(k).name);
    [audioIn,f] = audioread(file_name);
 
    nombre = files(k).name;
    nombre = nombre(1:end-4); %Extrae la extension de archivo
    nombre = strcat(nombre, '.png');
    nombre2 = strcat(nombre,'2','.png');
    % tipo 1: parametrizacion
    melSpectrogram(audioIn, f, ...
                                "Window", hann(2048,'periodic'),"OverlapLength", 1024,"FFTLength", 4096,...
                                "NumBands", 64);
    set(gca, 'Visible', 'off'); %Eliminacion de los ejes
    %colorbar('off'); % quita la barra de colores
    file_name = fullfile(folder_output, nombre); %Enrutamiento de imagen
    saveas(gcf,file_name);

    % tipo 2: parametrizacion
    melSpectrogram(audioIn, f, ...
                                "Window", hann(1024,'periodic'),"OverlapLength", 512,"FFTLength", 2048,...
                                "NumBands", 64);
    set(gca, 'Visible', 'off'); %Eliminacion de los ejes
    %colorbar('off'); % quita la barra de colores
    file_name = fullfile(folder_output, nombre2);%Enrutamiento de imagen
    saveas(gcf,file_name);

%end
