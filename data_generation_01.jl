using DataFrames
using XLSX
using Pipe
using StatsBase: sample

##
@time df = vcat(
    XLSX.readtable("data/CONOSCE_CONVOCATORIAS2018_0.xlsx", "CONOSCE") |> DataFrame,
    XLSX.readtable("data/CONOSCE_CONVOCATORIAS2019_0.xlsx", "CONOSCE") |> DataFrame,
    XLSX.readtable("data/CONOSCE_CONVOCATORIAS2020_0.xlsx", "CONOSCE") |> DataFrame,
    XLSX.readtable("data/CONOSCE_CONVOCATORIAS2021_0.xlsx", "CONOSCE") |> DataFrame,
    XLSX.readtable("data/CONOSCE_CONVOCATORIAS2022_0.xlsx", "CONOSCE") |> DataFrame,
    XLSX.readtable("data/CONOSCE_CONVOCATORIAS2023_0.xlsx", "CONOSCE") |> DataFrame,
    XLSX.readtable("data/CONOSCE_CONVOCATORIAS2024_0.xlsx", "CONOSCE") |> DataFrame,
)

## NOTE: Bienes
filtered_df = select(df, [
    :OBJETOCONTRACTUAL,
    :ENTIDAD,
    :DESCRIPCION_PROCESO,
    :N_ITEM, :DESCRIPCION_ITEM,
    :UNIDAD_MEDIDA,
    :PAQUETE,
    :CODIGOITEM,
    :ITEMCUBSO,
    :MONTO_REFERENCIAL_ITEM_SOLES]
)
filter!(:OBJETOCONTRACTUAL => ==("Bien"), filtered_df)
filtered_df = vcat([hcat(DataFrame(g[sample(1:size(g, 1)), :]), DataFrame(:Count => size(g, 1))) for g in groupby(filtered_df, :ITEMCUBSO)]...)
XLSX.writetable("data/ITEMCUBSO_2018_2024_Bienes.xlsx", filtered_df)

## NOTE: Clasificación CUBSO
segmentos_df = XLSX.readtable("data/cubso-al-04-11-2024.xlsx", "BIENES") |> DataFrame
const segmentos = [
    "10", "11", "12", "13", "14", "15",
    "20", "21", "22", "23", "24", "25", "26", "27",
    "30", "31", "32", "39",
    "40", "41", "42", "43", "44", "45", "46", "47", "48", "49",
    "50", "51", "52", "53", "54", "55", "56", "57",
    "60",
    "95",
]

find_segmento(x) = @pipe segmentos[findfirst(y -> startswith(x, y), segmentos)] |> join(["SEGMENTO", _], "_")
transform!(segmentos_df, "CÓDIGO" => ByRow(find_segmento) => :SEGMENTO).SEGMENTO
select!(segmentos_df, Not([:segmento, :segmento_name]))
rename!(segmentos_df, "TÍTULO" => :ITEMCUBSO)

## NOTE: leftjoin()
bienes_df = XLSX.readtable("data/ITEMCUBSO_2018_2024_Bienes.xlsx", "Sheet1") |> DataFrame
bienes_joined = leftjoin(
    bienes_df,
    select(segmentos_df, [:ITEMCUBSO, :SEGMENTO]),
    on=:ITEMCUBSO, matchmissing=:equal
)
XLSX.writetable("data/BIENES_2018_2024.xlsx", bienes_joined)

##
@pipe sort(bienes_joined, :Count, rev=true).SEGMENTO |> first(_, 50)

## 
#= transform!(df, :PROCESO => ByRow(x -> filter(y -> !isspace(y), x)) => :PROCESO) =#
#= procesos_validos = ["SEL-", "AS-", "CP-", "LP-", "PEC-", "SIE-"] # Accounts for approximately 75% of all processes =#
#= filtered_df = filter(:PROCESO => x -> any([startswith(p)(x) for p in procesos_validos]), df) =#
#= filter!([:ITEMCUBSO] => !ismissing, filtered_df) =#
#= filter!([:OBJETOCONTRACTUAL] => x -> x != "Bien", filtered_df) =#
#==#

##
df_ITEMCUBSO = XLSX.readtable("data/ITEMCUBSO_2018_2024.xlsx", "Sheet1") |> DataFrame

##
filter_labels = Set(["_non_informative", "_too_few_to_care", "_too_much", "_wrong"])
raw_data_01 = @pipe filter([:LABEL] => !ismissing, df_ITEMCUBSO) |>
                    filter([:LABEL] => x -> x ∉ filter_labels, _) |>
                    select(_, [:ITEMCUBSO, :LABEL]) |>
                    leftjoin(filtered_df, _, on=:ITEMCUBSO, matchmissing=:equal)

## WARNING:
sample_150x = vcat(
    [g[sample(1:size(g, 1), min(size(g, 1), 200), replace=false), :] for g in groupby(raw_data_01, :LABEL)]...
)
#= select(sample_150x, [:OBJETOCONTRACTUAL, :DESCRIPCION_PROCESO, :SISTEMA_CONTRATACION, :MONTO_REFERENCIAL_ITEM, :LABEL]) =#

##
#= XLSX.writetable("raw_data_01.xlsx", raw_data_01) =#
XLSX.writetable("raw_data_01_150x.xlsx", sample_150x)

##

df_ITEMCUBSO = XLSX.readtable("data/ITEMCUBSO_2018_2024.xlsx", "Sheet1") |> DataFrame
filter!(:OBJETOCONTRACTUAL => x -> x == "Bien", df_ITEMCUBSO)
XLSX.writetable("data/ITEMCUBSO_2018_2024_Bien.xlsx", df_ITEMCUBSO)

