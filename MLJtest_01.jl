using XLSX, DataFrames
using Pipe: @pipe
using MLJ, Flux, MLJFlux
using MLJText, TextAnalysis, Languages
using StatsBase: sample
import Optimisers

##

df = XLSX.readtable("data/filtered_procesos_04.xlsx", "Sheet1") |> DataFrame
gd = @pipe filter(:VERBO => !ismissing, df) |> select(_, ["VERBO", "OBJETO/TIPO"]) |> groupby(_, ["VERBO", "OBJETO/TIPO"])
gd_count = @pipe combine(gd, nrow => :count) |> sort(_, :count, rev=true)
filter(["VERBO", "OBJETO/TIPO"] => (x, y) -> !startswith("?")(x) && !startswith("?")(y), gd_count)

##

function procesar_str(str::String)
    sd = lowercase(str) |> StringDocument
    language!(sd, Languages.Spanish())
    prepare!(sd, strip_articles)
    prepare!(sd, strip_pronouns)
    prepare!(sd, strip_prepositions)
    prepare!(sd, strip_non_letters)
    prepare!(sd, strip_whitespace)
    return sd
end

function procesar_val(val::String)
    try
        parse(Float64, replace(val, "," => ""))
    catch
        0.0
    end
end

filtered_df = @pipe filter(:VERBO => !ismissing, df)

data = DataFrame(
    :objeto => procesar_str.(filtered_df."Objeto de Contratación"),
    :desc => procesar_str.(filtered_df."Descripción de Objeto"),
    :val => procesar_val.(filtered_df."Valor Referencial / Valor Estimado"),
    :label => Symbol.(filtered_df."VERBO" .* "_" .* filtered_df."OBJETO/TIPO")
)

#= foreach(normalize!, eachcol(data.val)) =#
##

corpus = Corpus(data.desc)
update_lexicon!(corpus)
lexicon(corpus)
m = DocumentTermMatrix(corpus)
#= tf(m) =#
#= tf_idf(m) =#
text_features = bm_25(m)
labels = data.label

## Encode labels as integers
unique_labels = unique(labels)
label_to_index = Dict(label => idx for (idx, label) in enumerate(unique_labels))
label_indices = [label_to_index[label] for label in labels]

# Convert labels to one-hot encoding
num_classes = length(unique_labels)
one_hot_labels = Flux.onehotbatch(label_indices, 1:num_classes)

# Ensure text features are of type Float32
text_features = Float32.(text_features)

# Step 2: Split data into training and testing sets
n_samples = size(text_features, 1)
train_indices = sample(1:n_samples, Int64(round(0.8 * n_samples)), replace=false) # 80% train
test_indices = setdiff(1:n_samples, train_indices) # remaining 20% test

train_features = text_features[train_indices, :]' # NOTE:
test_features = text_features[test_indices, :]'

train_labels = one_hot_labels[:, train_indices] # WARNING: This has to be run just once, that's why the error
test_labels = one_hot_labels[:, test_indices]

# Step 3: Define the model
model = Chain(
    Dense(2206 => 128, relu),   # Input layer: 2206 features -> 128 hidden
    Dense(128 => 64, relu),    # Hidden layer: 128 -> 64 hidden
    Dense(64 => num_classes),  # Output layer: 64 -> num_classes
    softmax                    # Convert logits to probabilities
)

# Step 4: Define the loss function
loss_function(ŷ, y) = Flux.logitcrossentropy(ŷ, y)

# Step 5: Define the optimizer
optimizer = Flux.Adam()

# Step 6: Create data loaders
batch_size = 64

train_loader = Flux.DataLoader((train_features, train_labels), batchsize=batch_size, shuffle=true)
test_loader = Flux.DataLoader((test_features, test_labels), batchsize=batch_size, shuffle=false)


## Step 7: Training loop
epochs = 10
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
        Flux.update!(optimizer, model, grads)
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

# Example usage
predictions = predict(model, test_features)

##

train_features
train_labels'

