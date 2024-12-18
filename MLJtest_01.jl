using XLSX, DataFrames
using Pipe: @pipe
using MLJ, Flux, MLJFlux
using MLJText, TextAnalysis, Languages
using StatsBase: sample
import Optimisers

## Loading the raw data

df = XLSX.readtable("data/filtered_procesos_04.xlsx", "Sheet1") |> DataFrame
gd = @pipe filter(:VERBO => !ismissing, df) |> select(_, ["VERBO", "OBJETO/TIPO"]) |> groupby(_, ["VERBO", "OBJETO/TIPO"])
gd_count = @pipe combine(gd, nrow => :count) |> sort(_, :count, rev=true)
filter(["VERBO", "OBJETO/TIPO"] => (x, y) -> !startswith("?")(x) && !startswith("?")(y), gd_count)

## Preprocessing the data

function procesar_str(str::String)
    sd = lowercase(str) |> StringDocument
    language!(sd, Languages.Spanish())
    prepare!(sd, strip_articles)
    prepare!(sd, strip_pronouns)
    prepare!(sd, strip_prepositions)
    prepare!(sd, strip_non_letters)
    prepare!(sd, strip_stopwords)
    prepare!(sd, strip_whitespace)
    return sd
end

function procesar_val(val::String)
    try
        parse(Float64, replace(val, "," => ""))
    catch
        missing
    end
end

objeto_de_contrat = ["Bien", "Consultoría de Obra", "Obra", "Servicio"]
map_objeto(s::String) = findfirst(x -> x == s, objeto_de_contrat)

##
location_words = [
    "poblado", "localidad", "distrito", "provincia", "departamento", "región",
    "poblados", "localidades", "distritos", "provincias",
]

function remove_unnecessary_words(s::String)
    s = lowercase(s) |> split

    for loc in location_words
        idx = findfirst(occursin.(loc, s))
        typeof(idx) == Int64 && (s = s[1:idx-1]; break)
    end

    return join(s, " ")
end

##

filtered_df = @pipe filter(:VERBO => !ismissing, df)

data = DataFrame(
    :objeto => map_objeto.(filtered_df."Objeto de Contratación"), # TEST: @benchmark it with String.(filtered_df."Obj...")
    :desc => procesar_str.(remove_unnecessary_words.(filtered_df."Descripción de Objeto")),
    :val => procesar_val.(filtered_df."Valor Referencial / Valor Estimado"),
    :label => Symbol.(filtered_df."VERBO" .* "_" .* filtered_df."OBJETO/TIPO")
)

## 

corpus = Corpus(data.desc)
update_lexicon!(corpus)
#= lexicon(corpus) =#
m = DocumentTermMatrix(corpus)
text_features = m.dtm # bm_25(m)
labels = data.label

## Encode labels as integers
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

train_features = hcat(data.objeto[train_indices], text_features[train_indices, :])' # NOTE: Understand
test_features = hcat(data.objeto[test_indices], text_features[test_indices, :])'

train_labels = one_hot_labels[:, train_indices]
test_labels = one_hot_labels[:, test_indices]

# Step 3: Define the model
model = Chain(
    Dense(size(text_features, 2) + 1 => 256 * 2, relu),   # Input layer: 2206 features -> 128 hidden
    #= Dense(256 * 2 => 128 * 2, relu),    # Hidden layer: 128 -> 64 hidden =#
    #= Dense(256 * 2 => 64, relu),    # Hidden layer: 128 -> 64 hidden =#
    Dense(256 * 2 => num_classes),  # Output layer: 64 -> num_classes
    softmax                    # Convert logits to probabilities
)

# Step 4: Define the loss function
loss_function(ŷ, y) = Flux.logitcrossentropy(ŷ, y)

# Step 5: Define the optimizer
#= optimizer = Flux.Adam() =#
# NOTE: Test -> Works!
opt_state = Flux.setup(Flux.Adam(), model)


# Step 6: Create data loaders
batch_size = 64 # NOTE: WHY?

train_loader = Flux.DataLoader((train_features, train_labels), batchsize=batch_size, shuffle=true)
test_loader = Flux.DataLoader((test_features, test_labels), batchsize=batch_size, shuffle=false)


## Step 7: Training loop
epochs = 200
for epoch in 1:epochs
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

# Step 8: Make predictions (optional)
function predict(model, features)
    ŷ = model(features)
    predictions = Flux.onecold(ŷ, 1:num_classes)
    return predictions
end

## Example usage
predictions = predict(model, test_features)
unique_labels[predictions]

res = DataFrame(trueLabel=labels[test_indices], predLabel=unique_labels[predictions])
DataFrames.transform!(res, [:trueLabel, :predLabel] => ByRow((x, y) -> x == y) => :results)
res.results |> sum

## INFO: PREDICTION

test_data = @pipe filter(:VERBO => ismissing, df)
test_data = DataFrame(
    :O => map_objeto.(test_data."Objeto de Contratación"),
    :SD => procesar_str.(test_data."Descripción de Objeto")
)
test_data = test_data[1:20, :]

lex = lexicon(corpus)

# Gotta loop, since broadcasting over dictionaries dtv.(test_data.SD, lex) is not possible
test_features_2 = Array{Int64}(undef, size(test_data, 1), length(lex) + 1)
for (i, sd) in enumerate(test_data.SD)
    test_features_2[i, 1] = test_data.O[i]
    test_features_2[i, 2:end] = dtv(sd, lex)
end
test_features_2 = test_features_2'

predictions_2 = predict(model, test_features_2)

for (i, pred) in enumerate(unique_labels[predictions_2])
    println(i, ": ", pred)
end
