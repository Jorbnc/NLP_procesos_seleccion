using DataFrames
using XLSX
using Pipe
using TextAnalysis
using Languages

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
size(filter([:verbo] => !ismissing, df_ITEMCUBSO)) == size(filter([:sustantivo] => !ismissing, df_ITEMCUBSO))

##
foo = @pipe filter([:sustantivo] => !ismissing, df_ITEMCUBSO) |>
            filter([:sustantivo] => x -> x != "*", _) |>
            select(_, [:ITEMCUBSO, :verbo, :sustantivo]) |>
            leftjoin(filtered_df, _, on=:ITEMCUBSO, matchmissing=:equal)

##

XLSX.writetable("foo.xlsx", foo)
