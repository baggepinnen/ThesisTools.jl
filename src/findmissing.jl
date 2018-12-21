
"""
find_missing(filename, opening_char, closing_char)

Locates missing brackets etc. in a Latex document.
Example: `find_missing(thesis.tex, '{', '}')
Does not work if opening and closing chars are the same, e.g., \$ \$
"""
function find_missing(filename, oc::AbstractChar, cc::AbstractChar, opens = [])
    @assert oc != cc "I do not work with matching opening and closing characters"
    (filename[end-3:end] == ".tex")  || @warn "This function was implemented to operate on .tex files. I will try anyway..."
    if !isempty(opens)
        @warn("Entering $filename with non-empty list of opened characters")
        @show opens
    end
    each_texline(filename) do lineno,line,file
        for char in line
            if char == oc
                push!(opens, (file, lineno))
            elseif char == cc
                if isempty(opens)
                    @info("Unexpected closing character found", file, lineno, line)
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
