const location_words = Set([
    "emp.", "km.", "emp", "km",
    "i.e", "i.e.",
    "jr", "jr.",
    "caserío", "caserio", "caseríos", "caserios",
    "comunidad", "comunidades",
    "sector", "sectores",
    "urbanización", "urbanizacion", "urbanizaciones",
    "poblado", "poblados",
    "localidad", "localidades",
    "distrito", "distritos",
    "provincia", "provincias",
    "departamento", "región",
    "meta",
])

function remove_unnecessary_words(str::String)
    s = split(str)

    for word in location_words
        println("Word")
        idx = findfirst(x -> x == word, s)
        try
            s = s[1:idx-1]
            break
        catch
            Nothing
        end
    end

    return join(s, " ")
end

function procesar_str(str::String)
    s = replace(str, "-" => " ", ":" => " ") |>
        lowercase |> remove_unnecessary_words
    sd = StringDocument(s)
    language!(sd, Languages.Spanish())
    prepare!(sd, strip_articles)
    prepare!(sd, strip_pronouns)
    prepare!(sd, strip_prepositions)
    prepare!(sd, strip_non_letters)
    prepare!(sd, strip_stopwords)
    prepare!(sd, strip_whitespace)
    return sd
end

function procesar_val(val::String)
    try
        parse(Float64, replace(val, "," => ""))
    catch
        missing
    end
end
