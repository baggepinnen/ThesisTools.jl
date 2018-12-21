module ThesisTools
export compile, splitsection, process, detex, word2vec, gettitlewords, find_missing, categorize, each_texline

include("findmissing.jl")

# using Embeddings, Clustering
# vocab2ind(vocab) = Dict(word=>ii for (ii,word) in enumerate(vocab))
# const _emb = load_embeddings(Word2Vec)
# const _vocab = vocab2ind(_emb.vocab)

using TextAnalysis, Test

"""
    each_texline(f, filename)
Tex-file iterator, call pattern:
```
each_texline(filename) do lineno,line,filename
    do something
end
```
"""
function each_texline(f, filename)
    inp = r"\\input{([\w_/]+.tex)}|\\include{([\w_/]+.tex)}"
    for (lineno,line) in enumerate(eachline(filename, keep=true))
        m = match(inp, line)
        if m != nothing # Enter new file
            each_texline(f, first_nonempty(m.captures))
            continue
        end
        if isempty(line) || line[1] == '%'
            continue
        end
        f(lineno,line,filename)
    end
end

"""
    text = compile(filename)
Return a string representing the tex-document. Follows \\input{} recursively.
See `process` for a function doing everyting you want ;)
"""
function compile(filename)
    io = IOBuffer()
    (filename[end-3:end] == ".tex")  || @warn "Provide a .tex file as input"
    each_texline(filename) do lineno,line,filename
        write(io, line)
    end
    String(take!(io))
end

first_nonempty(x) = x[1] == nothing ? first_nonempty(@view(x[2:end])) : x[1]

splitsection(text, ::Nothing) = text, nothing

"""
    sections::Vector{String}, headings = splitsection(text::String, sectionsplit::String)
Splits a string representing a tex document into a vector at the specified section level.
`sectionsplit` ∈ ["part", "chapter", "section", "subsection"...]
"""
function splitsection(text, sectionsplit)
    pattern = Regex("\\\\$(sectionsplit){([\\w\\s\\-]+)}")
    headings = collect((m.captures[1] for m = eachmatch(pattern, text)))
    insert!(headings, 1, "")
    split(text, pattern, keepempty=true), headings
end

"""
    text           = process(filename)
    text, headings = process(filename, sectionsplit::String)

Reads a tex file and removes all tex-code to produce a clean output without environments or commands (thus, all figure captions will be removed). If the optinal `sectionsplit` is set, splits the string into a vector at the specified section level.
`sectionsplit` ∈ ["part", "chapter", "section", "subsection"...]
"""
function process(filename, sectionsplit)
    text  = compile(filename)
    text, headings  = splitsection(text, sectionsplit)
    detex(text), headings
end

function process(filename)
    text  = compile(filename)
    detex(text)
end

detex(x::AbstractArray) = detex.(x)

"""
outputtext = detex(inputtext)

Removes preamble, environments and latex tags from the inputtext
"""
function detex(t)
    t = split(t, "\\begin{document}")[end] |> String
    t = replace(t, "\\end{document}" => "")
    t = replace(t, "~" => " ")
    t = replace(t, r"(\$\$*).+?\1" => " ") # Removes $x$ $$x$$ math (.{1,300}? the ? makes the . match as few as possible
    t = replace(t, r"\\begin{([\w\*]+?)}.*?\\end{\1}"s => " ")
    t = replace(t, r"\\\w{1,15}\**{.{1,100}}{.{1,100}}" => " ") # Removes commands with double arguments
    t = replace(t, r"\\cmt\{.*?\}" => " ") # Removes comments
    t = replace(t, r"\\\w{1,15}\**{.{1,100}}" => " ") # Removes commands with arguments
    t = replace(t, r"\\\w{1,15}" => " ") # Removes commands
    t = replace(t, r"\{|\}" => " ") # Removes leftover {}
    t
end

"""
embeddings, indices = word2vec(t)
`t` can be a sentence or a word. Returns vectors (one embedding for each word in `t`).
"""
function word2vec(t, emb = _emb)
    index   = vocab2ind(emb.vocab)
    words   = String.(split(t))
    key     = keys(index)
    indices = Int[]
    embeddings = Vector{Float32}[]
    for word in words
        if word in key
            push!(indices, index[word])
            push!(embeddings, emb.embeddings[:,indices[end]])
        end
    end
    embeddings, indices
end

"""
clustercenters = cluster(embeddings::Vector{Vector}, num_clusters)
Finds the cluster centers of the embedding vectors in `embeddings`.
"""
function cluster(embeddings, k)
    embeddings = hcat(embeddings...)
    res = Clustering.kmeans(embeddings, k)
    centers = map(1:k) do i
        res.centers[:,i]
    end
    map(centers) do center
        getclosest(center, k=k)
    end
end

getclosest(e, args...;kwargs...) = getclosest([e], args...;kwargs...)

"""
getclosest(embeddings::Vector{Vector}; k=1}
Finds the `k` nearest neighbors embedding
"""
function getclosest(embeddings::AbstractArray{<:AbstractArray}, emb = _emb; k = 1)
    meanembedding = reduce(+,embeddings)./length(embeddings)
    # dist(x,y) = sum(abs2,x-y)
    dist(x,y) = 1-x'y/norm(x)/norm(y)
    dists = map(1:size(emb.embeddings,2)) do i
        dist(emb.embeddings[:,i], meanembedding)
    end
    return emb.vocab[sortperm(dists)[1:k]]
end

"""
gettitlewords(inputstring, k=1)
Tries to find good titlewords based on an input string. Does not work that well tbh. Uses word2vec and clustering to find central words.
"""
function gettitlewords(t, k=1)
    emb = _emb
    d = StringDocument(t)
    prepare!(d, strip_articles | strip_stopwords | strip_pronouns | strip_numbers | strip_non_letters | strip_punctuation | strip_frequent_terms | strip_definite_articles)
    embeddings, indices = word2vec(d.text,emb)
    getclosest(cluster(embeddings, k), k=k)
end
# @test word2vec("test")[2][] == _vocab["test"]
# @test getclosest(word2vec("test")[1])[] == "test"


k_largest(array,k) = sortperm(array, rev=true)[1:k]

function gettopics(m,ϕ, words_per_topic = 30)
    k = size(ϕ,1)
    topics = map(1:k) do topic_num
        probs = Vector(ϕ[topic_num,:])
        inds_of_largest = k_largest(probs,words_per_topic)
        words = m.terms[inds_of_largest]
    end
    topics = hcat(topics...)
end

"""
function classify(crps, docid, verbose=true)

"""
function classify(crps, docid, verbose=true)
    verbose && print("\n"^10)
    verbose && println("Document:\n", replace(crps[docid].text[1:2000], r"\s+", " "))

    for id in 1:size(topics,2)
        if θ[id, docid] == 0
            continue
        end
        println("is $(θ[id, docid]) topic ")
        show(topics[:,id])
        println()
    end
end

"""
ϕ,θ,topics = categorize(crps, ntopics=8;
    iters           = 2010,     # number of gibbs sampling iters in lda
    α               = 1/ntopics,# hyper parameter topics per document
    β               = 0.001,    # hyper parameter words per topic
    words_per_topic = 30)

See `lda` for more help on options.
"""
function categorize(crps, ntopics=8;
    iters           = 2010,     # number of gibbs sampling iterss
    α               = 1/ntopics,# hyper parameter topics per document
    β               = 0.001,    # hyber parameter words per topic
    words_per_topic = 30)

    m   = DocumentTermMatrix(crps)
    ϕ,θ = lda(m, ntopics, iters, α, β)
    ϕ,θ,gettopics(m,ϕ, words_per_topic)
end


rules = Function[]
function find_common_errors(filename)
    for rule in rules
        rule(filename)
    end
end

function matchall(r,t)
    matches = RegexMatch[]
    i = 1
    while true
        m = match(r,t,i)
        if m === nothing
            return matches
        end
        i = m.offset + sum(length,m.captures)
        push!(matches, m)
    end
    matches
end

function rule_dash_or_not(filename)
    t = process(filename)
    dashed_matches = matchall(r"(\b\w{2,100}?)-(\w{4,100})", t)
    each_texline(filename) do lineno,line,filename
        for dashed_match in dashed_matches
            m = match(Regex(dashed_match[1]*dashed_match[2]), line)
            m === nothing && continue
            @info("Found both $(dashed_match.match) and $(m.match) in $filename at line $lineno")
        end
    end
end
push!(rules, rule_dash_or_not)

end # ThesisSummarizer
