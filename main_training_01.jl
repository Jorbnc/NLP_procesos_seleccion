using DataFrames, XLSX
using Pipe
using TextAnalysis, Languages
using StatsBase: sample
using Flux
using MLUtils

include("utils/text_preprocessing_01.jl")
include("utils/data_corpus_lex_M_01.jl")

##
data, OBJ_length = data_from_xlsx("raw_data_01.xlsx", "Sheet1") |> preprocess_data
corpus, lex, M = text_analysis(data)

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

# TODO: Stratified sampling required here
# Label Encoding
unique_labels = unique(labels)
label_to_index = Dict(label => idx for (idx, label) in enumerate(unique_labels))
label_indices = [label_to_index[label] for label in labels]

# Convert labels to one-hot encoding
num_classes = length(unique_labels)
one_hot_labels = Flux.onehotbatch(label_indices, 1:num_classes)

# Step 2: Split data into training and testing sets
function get_stratified_indices()
    train_indices = Vector{Int64}()
    test_indices = Vector{Int64}()
    for v in values(group_indices(labels))
        group_length = size(v, 1)
        s = sample(1:group_length, Int64(round(0.8 * group_length)), replace=false)
        sᶜ = setdiff(1:group_length, s)
        append!(train_indices, v[s])
        append!(test_indices, v[sᶜ])
    end
    return train_indices, test_indices
end

train_indices, test_indices = get_stratified_indices()

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

### WARNING: Loading a model state
model_state = JLD2.load("model_01_0_0150_x4.jld2", "model_state")
Flux.loadmodel!(model, model_state)

## Step 4: Define the loss function
loss_function(ŷ, y) = Flux.logitcrossentropy(ŷ, y)

# Step 5: Define the optimizer
opt_state = Flux.setup(Flux.Adam(0.001), model)

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

function prediction_threshold(model, features, threshold)
    model_output = model(features)
    res = Vector{Union{String,Missing}}()
    for col in eachcol(model_output)
        if maximum(col) < threshold
            push!(res, "?????")
        else
            out = unique_labels[Flux.onecold(col, 1:num_classes)]
            push!(res, out)
        end
    end
    return res
end

function eval_accuracy(X, indices)
    predictions = prediction(model, X)
    res = DataFrame(trueL=labels[indices], predL=unique_labels[predictions])
    DataFrames.transform!(res, [:trueL, :predL] => ByRow((x, y) -> x == y) => :results)
    acc = combine(groupby(res, :trueL), :results => (x -> sum(x) / length(x)) => :Accuracy)
    @show sum(res.results) / length(res.results)
    sort!(acc, :Accuracy)
    return acc
end

##
eval_accuracy(Xtrain, train_indices)

##
eval_accuracy(Xtest, test_indices)

##
seace_df = XLSX.readtable("data/Lista-Procesos.xlsx", "Sheet0") |> DataFrame
seace_df = DataFrame(
    :OBJETOCONTRACTUAL => map(map_objeto, seace_df."Objeto de Contratación"),
    :DESCRIPCION_PROCESO => map(procesar_str, seace_df."Descripción de Objeto"),
)
filter!(:OBJETOCONTRACTUAL => !isnothing, seace_df)

##
function predict_unseen(df::DataFrame)
    sample_row = hcat(df.OBJETOCONTRACTUAL[1], dtv(df.DESCRIPCION_PROCESO[1], lex))
    n, m = size(df, 1), length(sample_row)
    result_matrix = Matrix{eltype(sample_row)}(undef, n, m)
    for i in 1:n
        result_matrix[i, :] = hcat(df.OBJETOCONTRACTUAL[i], dtv(df.DESCRIPCION_PROCESO[i], lex))
    end
    X = Float32.(result_matrix)'
    DataFrame(
        :DESCRIPCION_PROCESO => [d.text for d in df.DESCRIPCION_PROCESO],
        :PREDICTION => prediction_threshold(model, X, 0.95)
    )
end

foo = predict_unseen(seace_df)
XLSX.writetable("unseen_pred_0150_x4.xlsx", foo)

## 
#= model_state = Flux.state(model) =#
#= jldsave("model_01_0_0150_x4.jld2"; model_state) =#
