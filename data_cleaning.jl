using XLSX
using DataFrames

## DATA

df1 = XLSX.readtable("data/Lista-Procesos-01.xlsx", "Sheet0") |> DataFrame
df2 = XLSX.readtable("data/Lista-Procesos-02.xlsx", "Sheet0") |> DataFrame
df3 = XLSX.readtable("data/Lista-Procesos-03.xlsx", "Sheet0") |> DataFrame
df4 = XLSX.readtable("data/Lista-Procesos-04.xlsx", "Sheet0") |> DataFrame
df_2023 = XLSX.readtable("data/Lista-Procesos-2023.xlsx", "Sheet0") |> DataFrame

## Tipos más frecuentes de procesos de selección
function get_nomenc_freq(df::DataFrame)
    f(s::String) = s[1:findfirst('-', s)-1]
    temp_df = select(df, :Nomenclatura => ByRow(f) => :Nomenclatura)
    combine(groupby(temp_df, :Nomenclatura), nrow => :Foo)
end

#= joined_df = outerjoin(get_nomenc_freq(df), get_nomenc_freq(df2), get_nomenc_freq(df3), get_nomenc_freq(df4), get_nomenc_freq(df_2023), =#
#=     on=:Nomenclatura, makeunique=true) =#
#==#
#= joined_df[!, :FooSum] = [sum(skipmissing(row)) for row in eachrow(joined_df[:, Not(:Nomenclatura)])] =#
#= joined_df |> sort =#

## Filtrar solo procesos válidos de la lista
procesos_validos = ["SEL", "AS", "CP", "LP", "PEC", "SCI", "SIE"]
filter_df(df::DataFrame) = filter(:Nomenclatura => x -> x[1:findfirst('-', x)-1] ∈ procesos_validos, df)
write_filtered_df(name::String, df::DataFrame) = XLSX.writetable(name, df)

filtered_df = filter_df(df_2023) #|> get_nomenc_freq # Comprobar
#= write_filtered_df("filtered_procesos_2023.xlsx", filtered_df) =#
