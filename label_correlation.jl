df = XLSX.readtable("data/filtered_procesos_04.xlsx", "Sheet1") |> DataFrame
no_missing_df = @pipe filter(:VERBO => !ismissing, df)

##
# Encode labels as integers
label1_unique = unique(no_missing_df."VERBO")
label2_unique = unique(no_missing_df."OBJETO/TIPO")
label1_encoded = map(x -> findfirst(==(x), label1_unique), no_missing_df."VERBO")
label2_encoded = map(x -> findfirst(==(x), label2_unique), no_missing_df."OBJETO/TIPO")

# Pearson correlation
pearson_corr = cor(label1_encoded, label2_encoded)
println("Pearson Correlation: $pearson_corr")

# Spearman correlation
spearman_corr = corspearman(label1_encoded, label2_encoded)
println("Spearman Correlation: $spearman_corr")

# NOTE: Low correlation between labels suggests that labels should be predicted separately
# i.e. train two DNN, one for each label
# NOTE: seq2seq (sequential prediction, like in translating tasks) is also discarded since
# those models are more suitable for larger sequences. Our case has only two elements.
