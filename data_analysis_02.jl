using XLSX
using DataFrames
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

## Frecuencias de los 4 tipos de OBJETOCONTRACTUAL

# Remove whitespaces from column :PROCESO
transform!(df, :PROCESO => ByRow(x -> filter(y -> !isspace(y), x)) => :PROCESO)

#= @pipe select(df, :PROCESO => ByRow(x -> x[1:findfirst('-', x)-1]) => :PROCESO) |> =#
#=       combine(groupby(_, :PROCESO), nrow => :count) |> =#
#=       sort(_, :count, rev=true) =#
#==#
##

procesos_validos = ["SEL-", "AS-", "CP-", "LP-", "PEC-", "SIE-"] # Accounts for approximately 75% of all processes
filtered_df = filter(:PROCESO => x -> any([startswith(p)(x) for p in procesos_validos]), df)
filter!([:ITEMCUBSO] => !ismissing, filtered_df)
#= select(filtered_df, :PROCESO => ByRow(x -> x[1:findfirst('-', x)-1])) |> unique =#

#= ITEMCUBSO_frequency = @pipe combine(groupby(filtered_df, [:ITEMCUBSO]), nrow => :count) |> sort(_, :count, rev=true) =#

##

# Get the first occurrence of each group, so I can inspect why a row has a particular ITEMCUBSO value
# INFO: Some unique :ITEMCUBSO are linked to (at least) two :OBJETOCONTRACTUAL, so by aggregating and taking
# the first occurrence, granularity and aggregated statistics for :OBJETOCONTRACTUAL will be different
# However, :ITEMCUBSO is more important for now
gdf_ITEMCUBSO = combine(groupby(filtered_df, [:ITEMCUBSO]),
    :ENTIDAD => first => :ENTIDAD,
    :CODIGOCONVOCATORIA => first => :CODIGOCONVOCATORIA,
    :PROCESO => first => :PROCESO,
    :DESCRIPCION_PROCESO => first => :DESCRIPCION_PROCESO,
    :DESCRIPCION_ITEM => first => :DESCRIPCION_ITEM,
    :UNIDAD_MEDIDA => first => :UNIDAD_MEDIDA,
    :OBJETOCONTRACTUAL => first => :OBJETOCONTRACTUAL,
    nrow => :count,
)
#= sort!(gdf_ITEMCUBSO, :ITEMCUBSO) =#

## WARNING: Adding existing labels

labeled_df = XLSX.readtable("data/ITEMCUBSO_2018_2024_bak.xlsx", "Sheet1") |> DataFrame
test_join = leftjoin(
    gdf_ITEMCUBSO,
    select(labeled_df, [:ITEMCUBSO, :verbo, :sustantivo]),
    on=:ITEMCUBSO, matchmissing=:equal
)

select!(test_join, [
    :ENTIDAD, :CODIGOCONVOCATORIA, :PROCESO, :DESCRIPCION_PROCESO, :DESCRIPCION_ITEM,
    :ITEMCUBSO, :verbo, :sustantivo, :UNIDAD_MEDIDA, :OBJETOCONTRACTUAL, :count]
)

##

sort(gdf_ITEMCUBSO.CODIGOCONVOCATORIA) == sort(test_join.CODIGOCONVOCATORIA) #NOTE: Mismas convocatorias

##
combine(groupby(filtered_df, :OBJETOCONTRACTUAL), nrow => :Counted)

##
combine(groupby(gdf_ITEMCUBSO, :OBJETOCONTRACTUAL), :count => sum)
