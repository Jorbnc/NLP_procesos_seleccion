using DataFrames
using XLSX
using Pipe

##

df = XLSX.readtable("data/filtered_procesos_04.xlsx", "Sheet1") |> DataFrame

##

gd = @pipe filter(:VERBO => !ismissing, df) |> select(_, ["VERBO", "OBJETO/TIPO"]) |> groupby(_, ["VERBO", "OBJETO/TIPO"])

gd_count = @pipe combine(gd, nrow => :count) |> sort(_, :count, rev=true)

filter(["VERBO", "OBJETO/TIPO"] => (x, y) -> !startswith("?")(x) && !startswith("?")(y), gd_count)

##



