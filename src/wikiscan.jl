import JSON #2190G
const f_en = open(joinpath(@__DIR__(), "entries.json"))
const arr_en = JSON.parse(f_en)
const words_en = [String(s[1]) for s in arr_en]
const regexes_en = [Regex(s[2]) for s in arr_en]
const subst_en = [Base.SubstitutionString(replace(s[3], "\$" => "\\")) for s in arr_en]



"""
    wikiscan(text, start = 1, regexes = regexes_en, words = words_en, subst = subst_en)

Scan for misspellings using wikipedia regexes.

# Arguments:
- `text`: The text to look in
- `start`: Line number to start at
- `regexes`: list of regexes to use
- `words`: Dictionary
- `subst`: List of substitution strings

# Credit: Jacob Wikmark, github.com/lancebeet
"""
function wikiscan(text, start = 1, regexes = regexes_en, words = words_en, subst = subst_en)
    lines = split(text, '\n')
    for (i,ln) in enumerate(lines[start:end])
        i % 100 == 0 && print("\1 ", i)
        for ind = 1:length(words)
            ma = eachmatch(regexes[ind], ln)
            out1 = "\nLine $i Regex $ind\n$ln\nMatch: $ma\n"
            out2 = ""
            for m in ma
                m = m.match
                sub = replace(m, regexes[ind] => subst[ind])
                if m != sub
                    out2 *= "$m : $sub\n"
                end
            end
            out2 == "" && continue
            print(out1)
            print(out2)
        end
    end
end
