## WARNING:
for g in groupby(data, :LABEL)
    println("🔴 ", g.LABEL[1])
    g_size = size(g, 1)
    idx = rand(1:g_size, min(g_size, 10))
    for x in g.DESCRIPCION_PROCESO[idx]
        println("⚫", x.text)
    end
    println()
end

## WARNING: DELETE
for d in filter(:DESCRIPCION_PROCESO => x -> occursin("av", x.text), data).DESCRIPCION_PROCESO
    println(d.text)
end

## WARNING: DELETE
baz = filter(:DESCRIPCION_PROCESO => x -> occursin("AV", x), df).DESCRIPCION_PROCESO

## WARNING: DELETE
for d in filter(:DESCRIPCION_PROCESO => x -> length(split(x.text)) < 4, data).DESCRIPCION_PROCESO
    println(d.text)
end
