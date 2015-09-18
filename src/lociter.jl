immutable LocationIterator{w,T}
    range::UnitRange{Int}
    index::FMIndex{w,T}
end

length(iter::LocationIterator) = length(iter.range)
@inline start(iter::LocationIterator) = 1
@inline done(iter::LocationIterator, i) = i > length(iter)
@inline next(iter::LocationIterator, i) = sa_value(iter.range[i], iter.index) + 1, i + 1
