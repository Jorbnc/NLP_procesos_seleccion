const words_set = Set([
    "emp", "km",
    "ie",
    "jr",
    "vecinal",
    "caserío", "caserio", "caseríos", "caserios",
    "comunidad", "comunidades",
    "sector", "sectores",
    "urbanización", "urbanizacion", "urbanizaciones",
    "poblado", "poblados",
    "localidad", "localidades",
    "distrito", "distritos",
    "provincia", "provincias",
    "departamento", "departamentos",
    "región", "region", "regiones",
    "meta",
    # 🔴
    "tramo",
    "av",
    "dv", "cu",
    "aahh", "hh",
    "asentamiento", "asentamientos", "humano", "humanos",
    "establecimiento", "establecimientos",
    "cp",
    "regional"
])

function remove_unnecessary_words_set(str::String)
    s = split(str)
    idx = findfirst(w -> w in words_set, s)
    return idx === nothing ? str : join(s[1:idx-1], " ")
end

function procesar_str(str::String)
    sd = replace(lowercase(str),
        "-" => " ",
        ":" => " ",
        "." => " ",
        "," => " ",
        "/" => " ",
        "=" => " ") |> StringDocument
    language!(sd, Languages.Spanish())
    prepare!(sd, strip_non_letters | strip_stopwords | strip_articles | strip_pronouns | strip_prepositions | strip_whitespace)
    sd = remove_unnecessary_words_set(sd.text) |> StringDocument
    return sd
end
