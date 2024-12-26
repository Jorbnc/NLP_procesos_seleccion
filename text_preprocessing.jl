#= const location_words = Set([ =#
#=     "emp.", "km.", "emp", "km", =#
#=     "i.e", "i.e.", =#
#=     "jr", "jr.", =#
#=     "caserío", "caserio", "caseríos", "caserios", =#
#=     "comunidad", "comunidades", =#
#=     "sector", "sectores", =#
#=     "urbanización", "urbanizacion", "urbanizaciones", =#
#=     "poblado", "poblados", =#
#=     "localidad", "localidades", =#
#=     "distrito", "distritos", =#
#=     "provincia", "provincias", =#
#=     "departamento", "región", =#
#=     "meta", =#
#= ]) =#
#==#
#= function remove_unnecessary_words(str::String) =#
#=     s = split(str) =#
#=     idx = findfirst(x -> x in location_words, s) =#
#=     return idx === nothing ? str : join(s[1:idx-1], " ") =#
#= end =#

##
location_words_vec = [
    "vecinal",
    "emp.", "emp", "km.", "km",
    "i.e", "i.e.",
    "jr", "jr.",
    "caserío", "caserio", "caseríos", "caserios",
    "comunidad", "comunidades",
    "sector", "sectores",
    "asentamiento", "asentamientos", "humano", "humanos",
    "urbanización", "urbanizacion", "urbanizaciones",
    "poblado", "poblados",
    "localidad", "localidades",
    "distrito", "distritos",
    "provincia", "provincias",
    "departamento", "región",
    "meta",
]
const location_priority = Dict(word => idx for (idx, word) in enumerate(location_words_vec))

function remove_unnecessary_words_test(str::String)
    s = split(str)  # Split string into words
    for (i, word) in enumerate(s)
        if haskey(location_priority, word)
            # Return string up to (but not including) the matched word
            return join(s[1:i-1], " ")
        end
    end
    return str  # Return original string if no match is found
end

function procesar_str(str::String)
    s = lowercase(replace(str, "-" => " ", ":" => " "))
    s = remove_unnecessary_words_test(s)
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

##












