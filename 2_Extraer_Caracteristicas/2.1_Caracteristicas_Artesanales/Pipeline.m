%% CARACTERISTICAS ARTESANALES DE URBANSOUND8K
% Script para la extraccion de las caracteristicas de cada muestra del dataset UrbanSound8k
clear, clc, close all;

% Ruta de Archivos de audio
folder_path = 'Input\siren';          % Carpeta de entrada
folder_middle = 'middle_folder';      % Carpeta de transicion de archivos
folder_done = 'Output\siren';         % Carpeta de guardado de csv
if ~exist(folder_path, 'dir')  
    error('Directorio no encontrado: %s', folder_path);
end

% Extraer los archivos .wav (excluye archivos . y ..)
files = dir(fullfile(folder_path, "*.wav"));
files = files(~[files.isdir]);
n_files = length(files);
fprintf('Numero de archivos: %d\n ',n_files);
% Categorias validas
categorias = {'air_conditioner','children_playing','drilling','engine_idling','jackhammer','siren','street_music'};

% Definicion de caracteristicas
features = {
    'ID',...
    'zcr',...                               % Zero Crossing Rate
    'ste_max',...                           % Short Time Energy - max
    'ste_min',...                           % Short Time Energy - min
    'ste_avg',...                           % Short Time Energy - average
    'log_attack_time',...                   % Log_attack_time
    'p_f',...                               % peak of frecuency
    'spectral_entropy', ...                 % Spectral Entropy
    'spectral_flux',    ...                 % Spectral Flux
    'category', ...                        % Categoria del audio
};

% Inicializacion de tabla de datos
featureTable = table();

for i = 1:n_files
    try
        % Leertura de archivos de audio
        file_path = fullfile(folder_path, files(i).name);
        [audioIn, Fs] = audioread(file_path);
        
        %Identificador de archivo
        id = string(files(i).name(1:end-4));

        % Preprocesamiento Inicial
        if size(audioIn, 2) == 2
            audioIn = mean(audioIn, 2);             % Convertir a mono
        end
        audioIn = audioIn - mean(audioIn);          % Eliminar DC offset

        % Configuraciion de parametros opcionlaes para algunas caracteristicas
        params = {'frame_length', round(0.03*Fs), 'overlap_ratio', 0.5, 'window', @hann};

        % Extraccion de caracteristicas 
        %1. Zero-crossing Rate
        zcr = zcr_function(audioIn,Fs,params{:});                            % Tasa desde 0 a 0.5
        %2. Short-Time Energy(STE)
        [ste_avg, ste_max, ste_min] = ste_function(audioIn,Fs, params{:});   % Adimensional
        %3. Log Attack Time (LAT)
        log_attack_time = LAT_function(audioIn, Fs);                         % Adimensional - db
        %4. Peak Frequency
        p_f = peak_frecuency_function(audioIn,Fs);                           % Hz
        %5. Spectral Flux and Entropy
        [spectral_flux, spectral_entropy] = spectral_flux_entropy(audioIn,Fs,params{:});  

        %Spectral Entropy se da en Bits 
        % Rango típico: Entre 0 (señal periódica perfecta, como un tono puro) y ~8-10 bits (ruido blanco o sonidos altamente caóticos).
        %Spectral flux es adimensional: 0.05 indica cambios espectrales suaves, mientras que 0.3 sugiere cambios bruscos.

        % Categoria del audio
        category = categorical("siren", categorias); 

        % Almacenar en tabla
         newRow = table(id, ...          
            zcr, ste_max,ste_min,ste_avg,log_attack_time, p_f,  ...
            spectral_entropy, spectral_flux, category, ...
            'VariableNames', features);
            featureTable = [featureTable; newRow];

         % Mover archivos a carpeta de transicion
         movefile(file_path, folder_middle);

    catch MensaggeError
        fprintf('Error procesando archivo %s: %s\n',files(i).name, MensaggeError.message);
    end
end

if ~isempty(files)
     movefile(fullfile(folder_middle, '*'), folder_path);  % Mueve todos los archivos de folder_middle a folder_path        
end
fprintf('Extraccion de caracteristicas finalizado correctamente de dir: %s\n', folder_path);

%% TABLA RESUMEN DE CARACTERISTICAS ESTADISTICAS
stadistic_table = removevars(featureTable, {'ID','category'});

% Calcular media y desviacion estandar
meanValues = varfun(@mean, stadistic_table, 'OutputFormat','table');
stdValues = varfun(@std, stadistic_table, 'OutputFormat','table');

% Renombrar variables para claridad
meanValues.Properties.VariableNames = stadistic_table.Properties.VariableNames;
stdValues.Properties.VariableNames = stadistic_table.Properties.VariableNames;

%Calculo de Cuartiles 
% Convertir tabla a matriz numérica
numericMatrix = table2array(stadistic_table);
% Calcular cuartiles (25%, 50%, 75%)
quartiles = quantile(numericMatrix, [0.25, 0.5, 0.75]);
% Convertir a tabla con nombres de columnas
quartileTable = array2table(quartiles, ...
    'VariableNames', stadistic_table.Properties.VariableNames, ...
    'RowNames', {'Q1', 'Mediana', 'Q3'});

% Crear tabla resumen combinada
summaryTable = [meanValues; stdValues; quartileTable];
summaryTable.Properties.RowNames = {'Media', 'Desviación Estándar', 'Q1', 'Mediana', 'Q3'};

% Guardar archivos en .CSV
featuresFile = fullfile(folder_done, 'caracteristicas_audio.csv');

% Guardar la tabla (incluye nombres de variables)
writetable(featureTable, featuresFile, 'WriteRowNames', false);

% Convertir nombres de filas a una columna adicional
summaryTableWithRowNames = addvars(summaryTable, summaryTable.Properties.RowNames, 'Before', 1, 'NewVariableNames', 'Estadistica');
% Guardar archivos de estadisticas CSV
statsFile = fullfile(folder_done, 'estadisticas_audio.csv');
% Guardar la tabla
writetable(summaryTableWithRowNames, statsFile, 'WriteRowNames', false);


function [flux, entropy] = spectral_flux_entropy(audioIn, Fs, varargin)
    [frames, ~, ~] = get_audio_frames(audioIn, Fs, varargin{:});
    num_frames = size(frames, 2);
    
    flux = 0;
    entropy = zeros(1, num_frames);
    prev_spectrum = [];
    
    for i = 1:num_frames
        frame = frames(:,i);
        spectrum = abs(fft(frame));
        half_spectrum = spectrum(1:floor(length(spectrum)/2)+1);
        
        % Entropía Espectral
        psd = (half_spectrum).^2 / (length(frame) * sum(frames(:,i).^2));
        psd_norm = psd / sum(psd);
        entropy(i) = -sum(psd_norm .* log2(psd_norm + eps)); % eps es una constante de precision relativa
        
        % Flujo Espectral
        if ~isempty(prev_spectrum)
            curr_norm = half_spectrum / sum(half_spectrum);  %Normalizacion de espectro acutla
            prev_norm = prev_spectrum / sum(prev_spectrum);
            flux = flux + sum((curr_norm - prev_norm).^2);
        end
        prev_spectrum = half_spectrum;
    end
    flux = flux / (num_frames - 1);
    entropy = mean(entropy);
end
function [peak_frequency] = peak_frecuency_function(audioIn, Fs)
        [Pxx, F] = pspectrum(audioIn, Fs);
        [~, idx] = max(Pxx);
        peak_frequency = F(idx);
end

function [LAT] = LAT_function(audioIn, Fs)
    audio_processed = get_audio_frames(audioIn, Fs, 'frame_length', length(audioIn), 'overlap_ratio', 0);
    energy = movmedian(audio_processed.^2, round(0.01*Fs)); % Suaviza el cálculo de energía
    threshold = 0.9 * max(energy);
    LAT = log10(find(energy >= threshold, 1) / Fs);
end

function [ste_avg, ste_max, ste_min] = ste_function(audioIn, Fs, varargin)
    [frames, ~, ~] = get_audio_frames(audioIn, Fs, varargin{:});
    energy = sum(frames.^2);
    ste_avg = mean(energy);
    ste_max = max(energy);
    ste_min = min(energy);
end

function [zcr] = zcr_function(audioIn, Fs, varargin)
    [frames, ~, ~] = get_audio_frames(audioIn, Fs, varargin{:});
    zcr = mean(sum(frames(1:end-1,:) .* frames(2:end,:) < 0, 1) ./ (size(frames,1) - 1));
end


function [frames, times, Fs] = get_audio_frames(audioIn, Fs, varargin)
    % Parámetros ajustables con valores por defecto
    p = inputParser;
    addParameter(p, 'frame_length', round(0.03 * Fs), @isnumeric);          % 30 ms
    addParameter(p, 'overlap_ratio', 0.75, @isnumeric);                     % 75% overlap
    addParameter(p, 'window', @hamming, @(x) isa(x, 'function_handle'));    % Ventana
    addParameter(p, 'normalize', true, @islogical); % Normalizar señal
    parse(p, varargin{:});  %varargin: ajuste de parametros frame_length, overlap_ratio, window, normalize
    
    frame_length = p.Results.frame_length;
    overlap = round(p.Results.overlap_ratio * frame_length);
    window_func = p.Results.window;
    normalize = p.Results.normalize;

    if normalize
        audioIn = audioIn / max(abs(audioIn));  % Normalizar amplitud
    end
    % Crear ventana
    win = window_func(frame_length);     
    % Dividir en ventanas con overlap
    frames = buffer(audioIn, frame_length, overlap, 'nodelay');  
    num_frames = size(frames, 2);
    % Aplicar ventana a cada frame
    frames = frames.* win;
    % Tiempos asociados a cada frame
    times = (0:num_frames-1) * (frame_length - overlap) / Fs;
end



