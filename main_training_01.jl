using DataFrames, XLSX
using Pipe
using TextAnalysis, Languages
using StatsBase: sample
using Flux
using MLUtils

include("text_preprocessing_01.jl")

## Funciones para obtener data de archivo .xlsx
function data_from_xlsx(file_path::String, sheet_name::String)
    # Leer el archivo .xlsx y filtrar filas con entradas :LABEL faltantes
    df = XLSX.readtable(file_path, sheet_name) |> DataFrame
    filter!(:LABEL => !ismissing, df)
    return df
end

function preprocess_data(df::DataFrame)
    # Preprocesar la data
    data = DataFrame(
        :DESCRIPCION_PROCESO => map(procesar_str, df.DESCRIPCION_PROCESO),
        :MONTO_REFERENCIAL_ITEM => df.MONTO_REFERENCIAL_ITEM,
        :LABEL => map(s -> s.LABEL, eachrow(df))
    )

    # Mapear (condicionalmente) el objeto contractual de los procesos: Consultoría de Obra, Obra, y Servicio 
    OBJETO_DICT = Dict(objeto => idx for (idx, objeto) in enumerate(["Consultoría de Obra", "Obra", "Servicio"]))
    map_objeto(s::String) = get(OBJETO_DICT, s, nothing)
    OBJ_column = df.OBJETOCONTRACTUAL
    OBJ_length = unique(OBJ_column) |> length
    OBJ_length > 1 && (data.OBJETOCONTRACTUAL = map(map_objeto, OBJ_column))

    # Filtrar únicamente descripciones con más de 2 palbras
    filter!(:DESCRIPCION_PROCESO => x -> length(split(x.text)) > 2, data)
    return data, OBJ_length
end

function text_analysis(data::DataFrame)
    # Agrupar todas las descripciones como un Corpus para analizarlas en conjunto
    corpus = Corpus(data.DESCRIPCION_PROCESO)

    # Generar un léxico con las ocurrencias y frecuencia de cada palabra
    update_lexicon!(corpus)
    lex = lexicon(corpus)
    lex = filter(x -> last(x) > 7, lex)

    # Filtrar aquellas palabras que ocurren más de una vez al year
    useful_keys = keys(lex) |> collect
    M = DocumentTermMatrix(corpus, useful_keys)

    return lex, M
end

##
@time data, OBJ_length = data_from_xlsx("raw_data_01.xlsx", "Sheet1") |> preprocess_data

##
@time lex, M = text_analysis(data)

## TODO: Encontrar un mejor gráfico. Esto debe ejecutarse con el lex original (i.e. lexicon(corpus))
vals = values(lex) |> collect
fig = Figure(size=(750, 375))
ax = Axis(fig[1, 1],
    #= title="Foo", =#
    xlabel="Frecuencia de la palabra", ylabel="Cantidad de palabras",
    yscale=Makie.pseudolog10, yticks=[0, 1, 10, 10^2, 10^3, 10^4, 10^5, 10^6],
    #= xscale=Makie.pseudolog10, =#
    xticks=[0, 7, 10^2, 10^3, 10^4, 10^5],
    xticklabelrotation=45,
)
hist!(vals, bins=200, strokewidth=1, strokecolor=:black)
display(fig)

##
objeto_features = Float32.(data.OBJETOCONTRACTUAL)
text_features = Float32.(M.dtm)
labels = data.LABEL

# Label Encoding
unique_labels = unique(labels)

# TODO: Stratified sampling required here
label_to_index = Dict(label => idx for (idx, label) in enumerate(unique_labels))
label_indices = [label_to_index[label] for label in labels]

# Convert labels to one-hot encoding
num_classes = length(unique_labels)
one_hot_labels = Flux.onehotbatch(label_indices, 1:num_classes)

# Step 2: Split data into training and testing sets
n_samples = size(text_features, 1)
train_indices = sample(1:n_samples, Int64(round(0.8 * n_samples)), replace=false) # 80% train
test_indices = setdiff(1:n_samples, train_indices) # remaining 20% test

Xtrain = hcat(objeto_features[train_indices], text_features[train_indices, :])' # NOTE: Understand
Xtest = hcat(objeto_features[test_indices], text_features[test_indices, :])'

Ytrain = one_hot_labels[:, train_indices]
Ytest = one_hot_labels[:, test_indices]

## Step 3: Define the model
model = Chain(
    Dense(size(text_features, 2) + 1 => 256 * 2, relu),
    Dense(256 * 2 => num_classes),
    softmax # Convert logits to probabilities
)

# WARNING: Loading a model state
#= model_state = JLD2.load("seace_model.jld2", "model_state") =#
#= Flux.loadmodel!(model, model_state) =#

## Step 4: Define the loss function
loss_function(ŷ, y) = Flux.logitcrossentropy(ŷ, y)

# Step 5: Define the optimizer
opt_state = Flux.setup(Flux.Adam(), model)

# Step 6: Create data loaders
batch_size = 128 # 10k
train_loader = Flux.DataLoader((Xtrain, Ytrain), batchsize=batch_size, shuffle=true)
test_loader = Flux.DataLoader((Xtest, Ytest), batchsize=batch_size, shuffle=false)

## Step 6: Training loop
epochs = 5
@time for epoch in 1:epochs
    @info "Epoch $epoch"
    # Entrenamiento
    for (x, y) in train_loader
        loss, grads = Flux.withgradient(model) do m
            ŷ = m(x)
            loss_function(ŷ, y)
        end
        Flux.update!(opt_state, model, grads[1])
    end
    # Evaluación
    train_loss = Flux.mean(Flux.logitcrossentropy(model(x), y) for (x, y) in train_loader)
    test_loss = Flux.mean(Flux.logitcrossentropy(model(x), y) for (x, y) in test_loader)
    @info "Train Loss: $train_loss, Test Loss: $test_loss"
end

## Step 8: Make predictions (optional)
function prediction(model, features)
    ŷ = model(features)
    predictions = Flux.onecold(ŷ, 1:num_classes)
    return predictions
end

## TEST: Prediction (same data)
predictions = prediction(model, Xtest)
unique_labels[predictions]

res = DataFrame(trueLabel=labels[test_indices], predLabel=unique_labels[predictions])
DataFrames.transform!(res, [:trueLabel, :predLabel] => ByRow((x, y) -> x == y) => :results)
#= sum(res.results) / length(res.results) =#

## TEST: Prediction (new data)


##
model_state = Flux.state(model)
jldsave("seace_model.jld2"; model_state)


