using DataFrames
using XLSX
using Pipe

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

##
transform!(df, :PROCESO => ByRow(x -> filter(y -> !isspace(y), x)) => :PROCESO)
procesos_validos = ["SEL-", "AS-", "CP-", "LP-", "PEC-", "SIE-"] # Accounts for approximately 75% of all processes
filtered_df = filter(:PROCESO => x -> any([startswith(p)(x) for p in procesos_validos]), df)
filter!([:ITEMCUBSO] => !ismissing, filtered_df)
filter!([:OBJETOCONTRACTUAL] => x -> x != "Bien", filtered_df)


##
df_ITEMCUBSO = XLSX.readtable("data/ITEMCUBSO_2018_2024.xlsx", "Sheet1") |> DataFrame

##
filter_labels = Set(["_non_informative", "_too_few_to_care", "_too_much", "_wrong"])
raw_data_01 = @pipe filter([:LABEL] => !ismissing, df_ITEMCUBSO) |>
                    filter([:LABEL] => x -> x ∉ filter_labels, _) |>
                    select(_, [:ITEMCUBSO, :LABEL]) |>
                    leftjoin(filtered_df, _, on=:ITEMCUBSO, matchmissing=:equal)

##
XLSX.writetable("raw_data_01.xlsx", raw_data_01)
