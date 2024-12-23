using DataFrames
using XLSX
using Pipe
using TextAnalysis
using Languages

##

df = XLSX.readtable("data/filtered_procesos_04.xlsx", "Sheet1") |> DataFrame

## See current data balance

gd = @pipe filter(:VERBO => !ismissing, df) |> select(_, ["VERBO", "OBJETO/TIPO"]) |> groupby(_, ["VERBO", "OBJETO/TIPO"])

gd_count = @pipe combine(gd, nrow => :count) |> sort(_, :count, rev=true)

filter(["VERBO", "OBJETO/TIPO"] => (x, y) -> !startswith("?")(x) && !startswith("?")(y), gd_count)

##

function procesar(str::String)
    sd = lowercase(str) |> StringDocument
    language!(sd, Languages.Spanish())
    prepare!(sd, strip_articles)
    prepare!(sd, strip_pronouns)
    prepare!(sd, strip_prepositions)
    prepare!(sd, strip_non_letters)
    return sd
end

data = @pipe filter(:VERBO => !ismissing, df) |> select(_, ["Descripción de Objeto", "VERBO", "OBJETO/TIPO"]) |> transform(_, ["VERBO", "OBJETO/TIPO"] => ByRow((x, y) -> Symbol(x * "_" * y)) => :label)

##
labels = @pipe data.label |> unique

nbc = NaiveBayesClassifier(labels)

transform!(data, ["Descripción de Objeto"] => ByRow(procesar) => :StringDocu)

for row in eachrow(data)
    fit!(nbc, row.StringDocu, row.label)
end

##

test_data = @pipe filter(:VERBO => ismissing, df) |> select(_, "Descripción de Objeto" => :S)
test_data = test_data[1:20, :]
results = transform(test_data, :S => ByRow(x -> argmax(predict(nbc, x))) => :Pred)

##

for (i, row) in enumerate(eachrow(results))
    println(i, ": ", row.S, " 🚀🚀🚀 ", row.Pred, "\n")
end
