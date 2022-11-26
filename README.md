# ThesisTools


This Julia package contains some tools I wrote while writing my [thesis](https://lup.lub.lu.se/search/publication/ffb8dc85-ce12-4f75-8f2b-0881e492f6c0).

# Functions
```julia
"""
    text, headings = process(filename, [sectionsplit::String])

Reads a tex file and removes all tex-code to produce a clean output without environments or commands (thus, all figure captions will be removed). If the optinal `sectionsplit` is set, splits the string into a vector at the specified section level.
`sectionsplit` ∈ ["part", "chapter", "section", "subsection"...]
"""
function process(filename, sectionsplit)
```
`process` is the main function, it takes your main tex file and compiles all text into a string by following `\include` and `\input` commands. It also detexes the string using the function `detex` below. If `sectionsplit` is provided, `text` will be a vector with, e.g., a string for each chapter/section etc.

---

```julia
"""
    text = compile(filename)
Return a string representing the tex-document. Follows \\input{} recursively.
See `process` for a function doing everyting you want ;)
"""
compile(filename)
```
`compile` handles the compilation of many separate tex-files into one string.

---

```julia
"""
outputtext = detex(inputtext)

Removes preamble, environments and latex tags from the inputtext
"""
function detex(t)
```
`detex` tries to remove all texiness from the string. It removes `\commands`, `$math$` and `$$math$$`, `% comments`, and all **environments** such as `\begin{figure} ... \end{figure}` (this means that all captions are removed also :/ )

---

```julia
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
```
`categorize` performs LDA on the corpus `crps`, see the usage example below.

---

```julia
"""
find_missing(filename, opening_char, closing_char)

Locates missing brackets etc. in a Latex document.
Example: `find_missing(thesis.tex, '{', '}')
Does not work if opening and closing chars are the same, e.g., \$ \$
"""
function find_missing(filename, oc, cc)
```

---

```julia
wikiscan(text)
```
Look for misspelled words etc. using Wikipedia regexes.



# Example usage
```julia
using ThesisTools, TextAnalysis
using TextAnalysis: sentence_tokenize, text
filename                    = "/local/home/fredrikb/phdthesis/phdthesis.tex";
chapters1, headings1        = process(filename, "chapter");
valid_chapter_inds          = length.(chapters1) .> 400;
valid_chapter_inds[[3,16]] .= false;
chapters                    = chapters1[valid_chapter_inds];
headings                    = headings1[valid_chapter_inds];
docs                        = StringDocument.(deepcopy(chapters));
crps                        = Corpus(deepcopy(docs));
prepare!(crps, strip_corrupt_utf8 | strip_case | strip_articles | strip_prepositions | strip_pronouns | strip_stopwords | strip_whitespace | strip_non_letters | strip_numbers)

# stem!(crps)
update_lexicon!(crps)
ϕ,θ,topics = ThesisTools.categorize(crps, 4); # LDA: Latent Dirichlet Allocation, takes about 10 seconds for a 160 page thesis and 4 categories.

julia> topics
30×4 Array{String,2}:
 "model"        "calibration"   "robot"         "model"
 "friction"     "matrix"        "seam"          "system"
 "functions"    "methods"       "sensor"        "time"
 "basis"        "data"          "measurement"   "learning"
 "function"     "method"        "error"         "models"
 "estimation"   "estimate"      "filter"        "dynamics"
 "signal"       "thesis"        "laser"         "function"
 "parameters"   "using"         "particle"      "optimization"
 "proposed"     "parameters"    "errors"        "linear"
 "position"     "linear"        "measurements"  "trajectory"
 "models"       "plane"         "trajectory"    "data"
 "spectral"     "sensor"        "uncertainty"   "regularization"
 "temperature"  "set"           "distribution"  "identification"
 "estimated"    "laser"         "forces"        "algorithm"
 "using"        "system"        "model"         "control"
 "matrix"       "based"         "estimation"    "jacobian"
 "method"       "frame"         "gaussian"      "prior"
 "parameter"    "procedure"     "estimator"     "noise"
 "velocity"     "algorithm"     "space"         "parameters"
 "data"         "vector"        "fsw"           "input"
 "dependence"   "approach"      "tracking"      "methods"
 "form"         "coordinate"    "forward"       "nonlinear"
 "due"          "initial"       "process"       "using"
 "squares"      "flange"        "tool"          "form"
 "varying"      "machine"       "function"      "optimal"
 "estimate"     "found"         "sensors"       "systems"
 "linear"       "kinematic"     "based"         "solution"
 "methods"      "optimization"  "deflections"   "weight"
 "dependent"    "research"      "kinematics"    "decay"
 "motor"        "rotation"      "modeling"      "network"

julia> topicnames = [ # These have to be manually arranged based on the words appearing in `topcis`
       "Modeling",
       "State Estimation and Calibration",
       "Robotics",
       "Learning Dynamics",
       ];

julia> using Plots

julia> heatmap(θ, yticks=(1:4, topicnames),xticks=(1:length(headings), headings), ylabel="Topic", xlabel="Chapter", size=(2000,600), color=:blues, xrotation=45);gui()
```
![window](lda.png)
