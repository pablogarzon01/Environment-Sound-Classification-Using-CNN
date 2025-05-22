
def optimize_finetuning_params(model_base, train_ds, val_ds, fine_tune_at_list, lr_list, epochs_list, class_names):
    """
    Realiza búsqueda de hiperparámetros para el fine-tuning de un modelo CNN ya entrenado con Transfer Learning.

    Parámetros:
        model_base (tf.keras.Model): Modelo entrenado previamente (TL).
        train_ds, val_ds: Dataset de entrenamiento y validación.
        fine_tune_at_list (list): Lista de índices de capa para descongelar.
        lr_list (list): Lista de learning rates a evaluar.
        epochs_list (list): Lista de valores de épocas a usar.
        class_names (list): Lista de nombres de clases para clasificación.

    Retorna:
        dict: La mejor combinación y el historial de resultados.
    """
    best_config = None
    best_macro_f1 = -1
    results_log = []

    for fine_tune_at in fine_tune_at_list:
        for lr in lr_list:
            for epochs in epochs_list:
                print(f"\n Probando: FT@{fine_tune_at}, LR={lr}, Epochs={epochs}")
                
                # Clonar modelo base para evitar modificar el original
                model = tf.keras.models.clone_model(model_base)
                model.set_weights(model_base.get_weights())

                # Entrenar fine-tuning
                cpu_usage, mem_usage, gpu_usage = [], [], []
                try:
                    history = fine_tune_model(
                        model,
                        train_ds,
                        val_ds,
                        base_learning_rate=lr,
                        fine_tune_at=fine_tune_at,
                        epochs=epochs,
                        cpu_usages=cpu_usage,
                        memory_usages=mem_usage,
                        gpu_usages=gpu_usage
                    )

                    y_true, y_pred, y_probs, report = get_classification_metrics(model, val_ds, class_names)

                    macro_f1 = report["macro avg"]["f1-score"]
                    val_loss = history.history["val_loss"][-1]
                    train_loss = history.history["loss"][-1]

                    # Detección de overfitting 
                    if val_loss > train_loss * 1.5:
                        print(" Overfitting detectado. Saltando configuración...")
                        continue

                    print(f" Macro F1: {macro_f1:.4f}")

                    results_log.append({
                        "fine_tune_at": fine_tune_at,
                        "lr": lr,
                        "epochs": epochs,
                        "macro_f1": macro_f1
                    })

                    if macro_f1 > best_macro_f1:
                        best_macro_f1 = macro_f1
                        best_config = {
                            "fine_tune_at": fine_tune_at,
                            "learning_rate": lr,
                            "epochs": epochs,
                            "macro_f1": macro_f1
                        }

                except Exception as e:
                    print(f" Error en configuración: {e}")
                    continue

    print("\n Mejor configuración:")
    print(best_config)
    return best_config, results_log



#---------------- SECCION DE INICIO DEL CODIGO ----------------------------------
if __name__ = "__main__" :
    # Ruta de conjunto de datos a emplear
    data_paths =  "..\\..\\Analisis_Espectros\\DataSetImages_FULL\\DataSetImages\\Spectrograms\\Mel-512"
    
    train_ds, val_ds, class_names = load_and_preprocess_data(data_paths)
    
    num_classes = len(class_names)
    
    # Crear modelo base para la representación actual
    model_tl = create_modelResnet101V2(num_classes)
    # Hiperparametros pre-establecidos para el entrenamiento
    ft_list = [320, 350, 365]
    lr_list = [1e-4, 1e-5, 1e-6]
    ep_list = [30]
    
    best_ft_params, results_ft = optimize_finetuning_params(
        model_tl, train_ds, val_ds,
        fine_tune_at_list=ft_list,
        lr_list=lr_list,
        epochs_list=ep_list,
        class_names=class_names
    )

