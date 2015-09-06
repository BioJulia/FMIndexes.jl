immutable LocationIterator{w,T}
    range::UnitRange{Int}
    index::FMIndex{w,T}
end

Base.length(iter::LocationIterator) = length(iter.range)
@inline Base.start(iter::LocationIterator) = 1
@inline Base.done(iter::LocationIterator, i) = i > length(iter)
@inline function Base.next(iter::LocationIterator, i)
    return sa_value(iter.range[i], iter.index) + 1, i + 1
end
