using DataFrames, XLSX
using Pipe
using TextAnalysis, Languages
using StatsBase: sample
using Flux, MLJ
#= import Optimisers =#
include("text_preprocessing.jl")

## Funciones para obtener data de archivo .xlsx
const OBJETO_DICT = Dict(objeto => idx for (idx, objeto) in enumerate(["Consultoría de Obra", "Obra", "Servicio"]))
map_objeto(s::String) = get(OBJETO_DICT, s, nothing)

# Leer .xlsx y filtrar filas con entradas :LABEL faltantes
function data_from_xlsx(file_path::String, sheet_name::String)
    df = XLSX.readtable(file_path, sheet_name) |> DataFrame
    filter!(:LABEL => !ismissing, df)
    return df
end

# Preprocesar data relevante para el modelo + Filtrar input con menos de 2 palabras
function preprocess_data(df::DataFrame)
    data = DataFrame(
        :DESCRIPCION_PROCESO => map(procesar_str, df.DESCRIPCION_PROCESO),
        :MONTO_REFERENCIAL_ITEM => df.MONTO_REFERENCIAL_ITEM,
        :LABEL => map(s -> s.LABEL, eachrow(df))
    )
    # 
    OBJ_column = df.OBJETOCONTRACTUAL
    OBJ_length = unique(OBJ_column) |> length
    OBJ_length > 1 && (data.OBJETOCONTRACTUAL = map(map_objeto, OBJ_column))
    # Filtrar únicamente descripciones con más de 2 palbras
    filter!(:DESCRIPCION_PROCESO => x -> length(split(x.text)) > 2, data)
    return data, OBJ_length
end

##
@time data, OBJ_length = data_from_xlsx("raw_data_01.xlsx", "Sheet1") |> preprocess_data

##
corpus = Corpus(data.DESCRIPCION_PROCESO)
update_lexicon!(corpus)
lex = lexicon(corpus)

##
m = DocumentTermMatrix(corpus)

##
text_features = Float32.(m.dtm)
objeto_features = Float32.(data.OBJETOCONTRACTUAL)
labels = data.LABEL

## Label Encoding
unique_labels = unique(labels)
label_to_index = Dict(label => idx for (idx, label) in enumerate(unique_labels))
label_indices = [label_to_index[label] for label in labels]

# Convert labels to one-hot encoding
num_classes = length(unique_labels)
one_hot_labels = Flux.onehotbatch(label_indices, 1:num_classes)

# Step 2: Split data into training and testing sets
n_samples = size(text_features, 1)
train_indices = sample(1:n_samples, Int64(round(0.8 * n_samples)), replace=false) # 80% train
test_indices = setdiff(1:n_samples, train_indices) # remaining 20% test

train_features = hcat(objeto_features[train_indices], text_features[train_indices, :])' # NOTE: Understand
test_features = hcat(objeto_features[test_indices], text_features[test_indices, :])'

train_labels = one_hot_labels[:, train_indices]
test_labels = one_hot_labels[:, test_indices]

## Step 3: Define the model
model = Chain(
    Dense(size(text_features, 2) + 1 => 256 * 2, relu),
    #= Dense(256 * 2 => 128 * 2, relu), =#
    #= Dense(256 * 2 => 64, relu), =#
    Dense(256 * 2 => num_classes),
    softmax # Convert logits to probabilities
)

##
#= model_state = JLD2.load("seace_model.jld2", "model_state") =#
#= Flux.loadmodel!(model, model_state) =#

## Step 4: Define the loss function
loss_function(ŷ, y) = Flux.logitcrossentropy(ŷ, y)

# Step 5: Define the optimizer
opt_state = Flux.setup(Flux.Adam(), model)

# Step 6: Create data loaders
batch_size = 10_000 # NOTE: WHY?
train_loader = Flux.DataLoader((train_features, train_labels), batchsize=batch_size, shuffle=true)
test_loader = Flux.DataLoader((test_features, test_labels), batchsize=batch_size, shuffle=false)

## Step 6: Training loop
epochs = 50
@time for epoch in 1:epochs
    @info "Epoch $epoch"
    # Training phase
    for (x, y) in train_loader
        # Forward pass
        loss, grads = Flux.withgradient(model) do m
            ŷ = m(x)
            loss_function(ŷ, y)
        end
        #
        # Update weights
        #= Flux.update!(optimizer, model, grads) =#
        Flux.update!(opt_state, model, grads[1])
    end

    # Evaluation phase
    train_loss = mean(Flux.logitcrossentropy(model(x), y) for (x, y) in train_loader)
    test_loss = mean(Flux.logitcrossentropy(model(x), y) for (x, y) in test_loader)
    @info "Train Loss: $train_loss, Test Loss: $test_loss"
end

## Step 8: Make predictions (optional)
function prediction(model, features)
    ŷ = model(features)
    predictions = Flux.onecold(ŷ, 1:num_classes)
    return predictions
end

## INFO: Prediction (same data)
predictions = prediction(model, test_features)
unique_labels[predictions]

res = DataFrame(trueLabel=labels[test_indices], predLabel=unique_labels[predictions])
DataFrames.transform!(res, [:trueLabel, :predLabel] => ByRow((x, y) -> x == y) => :results)
sum(res.results) / length(res.results)

## INFO: Prediction (new data)


##
model_state = Flux.state(model)
jldsave("seace_model.jld2"; model_state)


