%% CARACTERISTICAS ARTESANALES DE URBANSOUND8K (Versión Optimizada)
clear, clc, close all;

% Configuración de rutas
folder_path = 'Input\siren';          % Carpeta de entrada (la categoría está en el nombre)
folder_middle = 'middle_folder';      % Carpeta temporal
folder_done = 'Output2';              % Carpeta de resultados

categorias = {'air_conditioner','children_playing','drilling','engine_idling','jackhammer','siren','street_music'};

% Extraer categoria del path 
path_parts = strsplit(folder_path, '\');                %Separacion de la ruta
input_index = find(strcmpi(path_parts, 'Input'), 1);
category_name = path_parts{input_index + 1};
category_name = cellstr(category_name);
category = categorical(category_name, categorias);


% Configuración de parámetros comunes
files = dir(fullfile(folder_path, "*.wav"));
files = files(~[files.isdir]);
n_files = length(files);
fprintf('Procesando %d archivos en: %s\n', n_files, folder_path);

% Prealocación de memoria para la tabla
featureTable = cell(n_files, 1);

% Parámetros de procesamiento de audio
params = {'frame_length', 512, 'overlap_ratio', 0.75, 'window', @hamming}; % Valores típicos para 16kHz

% Procesamiento principal
for i = 1:n_files
    try
        % 1. Cargar y preprocesar audio
        file_path = fullfile(folder_path, files(i).name);
        [audioIn, Fs] = audioread(file_path);
        
        % Conversión a mono y eliminación de DC offset
        audioIn = mean(audioIn, 2);         % Mono
        audioIn = audioIn - mean(audioIn);  % DC offset
         audioIn = audioIn / max(abs(audioIn));  % Normalización 
        % 2. Procesamiento común 
        [frames, ~, ~] = get_audio_frames(audioIn, Fs, params{:});
        
        % 3. Extracción de características
        zcr = zcr_function(frames);
        [ste_avg, ste_max, ste_min] = ste_function(frames);
        [spectral_flux, spectral_entropy] = spectral_flux_entropy(frames, Fs);
        log_attack_time = LAT_function(audioIn, Fs);
        p_f = peak_frecuency_function(audioIn, Fs);
        
        % 4. Crear fila de la tabla
        newRow = table(...
            string(files(i).name(1:end-4)),...  % ID
            zcr, ste_max, ste_min, ste_avg,...
            log_attack_time, p_f,...
            spectral_entropy, spectral_flux,...
            category,...                       % Categoría
            'VariableNames', {'ID','zcr','ste_max','ste_min','ste_avg',...
            'log_attack_time','p_f','spectral_entropy','spectral_flux','category'});
        
        featureTable{i} = newRow;
        
        % 5. Mover archivo procesado
        movefile(file_path, folder_middle);
        
    catch ME
        fprintf('Error en %s: %s\n', files(i).name, ME.message);
    end
end

% Mover archivos de vuelta al directorio original
if ~isempty(files)
     movefile(fullfile(folder_middle, '*'), folder_path);  % Mueve todos los archivos de folder_middle a folder_path        
end

% Consolidar tabla final
featureTable = vertcat(featureTable{:});

%% Generación de reportes y guardado
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

%% Funciones optimizadas (modificadas para trabajar con frames precalculados)
function [zcr] = zcr_function(frames)
    zcr = mean(sum(frames(1:end-1,:) .* frames(2:end,:) < 0, 1) ./ (size(frames,1)-1));
end

function [ste_avg, ste_max, ste_min] = ste_function(frames)
    energy = sum(frames.^2);
    ste_avg = mean(energy);
    ste_max = max(energy);
    ste_min = min(energy);
end

function [flux, entropy] = spectral_flux_entropy(frames, Fs)
    num_frames = size(frames, 2);
    flux = 0;
    entropy = zeros(num_frames, 1);
    prev_spectrum = [];
    
    for i = 1:num_frames
        frame = frames(:,i);
        spectrum = abs(fft(frame));
        half_spectrum = spectrum(1:floor(end/2)+1);
        
        % Entropía espectral
        psd = (half_spectrum).^2 / (length(frame)*sum(frame.^2));
        psd_norm = psd / sum(psd);
        entropy(i) = -sum(psd_norm .* log2(psd_norm + eps));
        
        % Flux espectral
        if ~isempty(prev_spectrum)
            diff = norm(half_spectrum - prev_spectrum)^2;
            flux = flux + diff;
        end
        prev_spectrum = half_spectrum;
    end
    flux = flux / (num_frames-1);
    entropy = mean(entropy);
end

function [LAT] = LAT_function(audioIn, Fs)
    energy = movmedian(audioIn.^2, round(0.01*Fs));
    threshold = 0.9 * max(energy);
    attack_sample = find(energy >= threshold, 1, 'first');
    LAT = log10((attack_sample + eps)/Fs); % Evitar log(0)
end

function [peak_frequency] = peak_frecuency_function(audioIn, Fs)
    [Pxx, F] = pspectrum(audioIn, Fs);
    [~, idx] = max(Pxx);
    peak_frequency = F(idx);
end

function [frames, times, Fs] = get_audio_frames(audioIn, Fs, varargin)
    p = inputParser;
    addParameter(p, 'frame_length', 512, @isnumeric);
    addParameter(p, 'overlap_ratio', 0.75, @isnumeric);
    addParameter(p, 'window', @hamming, @(x) isa(x, 'function_handle'));
    parse(p, varargin{:});
    
    frame_length = p.Results.frame_length;
    overlap = round(p.Results.overlap_ratio * frame_length);
    win = p.Results.window(frame_length);
    
    frames = buffer(audioIn, frame_length, overlap, 'nodelay');
    frames = frames .* win;
    times = (0:size(frames,2)-1) * (frame_length - overlap) / Fs;
end