struct LocationIterator{w,T}
    range::UnitRange{Int}
    index::FMIndex{w,T}
end

Base.length(iter::LocationIterator) = length(iter.range)

function Base.iterate(iter::LocationIterator, i::Int=1)
    if i > length(iter)
        return nothing
    end
    return sa_value(iter.range[i], iter.index) + 1, i + 1
end
