## Funciones para obtener data de archivo .xlsx
function data_from_xlsx(file_path::String, sheet_name::String)
    # Leer el archivo .xlsx y filtrar filas con entradas :LABEL faltantes
    df = XLSX.readtable(file_path, sheet_name) |> DataFrame
    filter!(:LABEL => !ismissing, df)
    return df
end

# BUG: Use onehotencoding instead
const OBJETO_DICT = Dict(objeto => idx for (idx, objeto) in enumerate(["Consultoría de Obra", "Obra", "Servicio"]))
map_objeto(s::String) = get(OBJETO_DICT, s, nothing)

function preprocess_data(df::DataFrame)
    # Preprocesar la data
    data = DataFrame(
        :DESCRIPCION_PROCESO => map(procesar_str, df.DESCRIPCION_PROCESO),
        :MONTO_REFERENCIAL_ITEM => df.MONTO_REFERENCIAL_ITEM,
        :LABEL => map(s -> s.LABEL, eachrow(df))
    )

    # Mapear (condicionalmente) el objeto contractual de los procesos: Consultoría de Obra, Obra, y Servicio 
    OBJ_column = df.OBJETOCONTRACTUAL
    OBJ_length = unique(OBJ_column) |> length
    OBJ_length > 1 && (data.OBJETOCONTRACTUAL = map(map_objeto, OBJ_column))

    # Filtrar únicamente descripciones con más de 2 palbras
    filter!(:DESCRIPCION_PROCESO => x -> length(split(x.text)) > 2, data)
    return data, OBJ_length
end

"""
For a given label, get rid of those terms that are present within only a threshold of the documents.

Default threshold = 0.005
"""
function discard_too_sparse_terms(label::String; threshold=0.0150)
    fdata = filter(:LABEL => x -> x == label, data)
    fdata_corpus = Corpus(fdata.DESCRIPCION_PROCESO)
    update_lexicon!(fdata_corpus)
    U = lexicon(fdata_corpus) |> keys |> collect |> Set
    S = sparse_terms(fdata_corpus, threshold) |> Set
    return setdiff(U, S)
end

function label_sparse_terms_Dict()
    labels = data.LABEL |> unique
    sparse_terms_Dict = Dict{String,Set{String}}()
    for label in labels
        println(label)
        sparse_terms_Dict[label] = discard_too_sparse_terms(label)
    end
    return sparse_terms_Dict
end


function text_analysis(data::DataFrame)
    # Agrupar todas las descripciones como un Corpus para analizarlas en conjunto
    corpus = Corpus(data.DESCRIPCION_PROCESO)

    # Obtener términos dispersos (muy infrecuentes)
    lstDict = label_sparse_terms_Dict()
    relevant_words = [word for word in union(values(lstDict)...)]

    # Generar un léxico con las ocurrencias y frecuencia de cada palabra
    update_lexicon!(corpus)
    lex = lexicon(corpus)
    filter!(x -> first(x) ∈ relevant_words, lex)
    M = DocumentTermMatrix(corpus, lex)

    return corpus, lex, M
end
