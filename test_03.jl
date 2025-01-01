using TextAnalysis, Languages

##
corpus = Corpus([
    StringDocument("Ejecución obra riego Chota"),
    StringDocument("Ejecución obra riego tecnificado Chota"),
    StringDocument("Ejecución riego tecnificado"),
    StringDocument("Instalación obra riego local"),
    StringDocument("Instalación puente local"),
    StringDocument("Ejecución obra puente Chota"),
    StringDocument("Ejecución puente Cajamarca"),
    StringDocument("Ejecución obra educativa"),
    StringDocument("Instalación educativa Chota"),
    StringDocument("Instalación educativa Chota Chota Chota Chota"),#
])

update_lexicon!(corpus)
m = DocumentTermMatrix(corpus)
lexicon(corpus)

##
s = sum(M.dtm, dims=2)
findfirst(x -> x == maximum(s), s)

##

string.(split("Uno dos tres tres tres") |> unique)
