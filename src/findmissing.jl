

"""
find_missing(filename, opening_char, closing_char)

Locates missing brackets etc. in a Latex document.
Example: `find_missing(thesis.tex, '{', '}')
Does not work if opening and closing chars are the same, e.g., \$ \$
"""
function find_missing(filename, oc::AbstractChar, cc::AbstractChar, opens = [])
    @assert oc != cc "I do not work with matching opening and closing characters"
    (filename[end-3:end] == ".tex")  || @warn "This function was implemented to operate on .tex files. I will try anyway..."
    inp = r"\\input{([\w_/]+.tex)}"
    if !isempty(opens)
        @warn("Entering $filename with non-empty list of opened characters")
        @show opens
    end
    for (lineno,line) in enumerate(eachline(filename))
        m = match(inp, line)
        if m != nothing # Enter new file
            find_missing(m.captures[1], oc, cc, opens)
            continue
        end
        if isempty(line) || line[1] == '%'
            continue
        end
        for char in line
            if char == oc
                push!(opens, (filename, lineno))
            elseif char == cc
                if isempty(opens)
                    @info("Unexpected closing character found", filename, lineno, line)
                    @info("Continuing with a count of 0")
                else
                    pop!(opens)
                end
            end

        end
    end
    if !isempty(opens)
        filename, lineno = opens[end]
        @info("Non matched opening character found", filename, lineno)
    end
end
