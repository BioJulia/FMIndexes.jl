module FMIndices

export FMIndex, restore, count, locate, locateall

import Base: count

using SuffixArrays
using WaveletMatrices
using IndexableBitVectors

# n: number of bits required to encode the alphabet
# T: type to represent the position
immutable FMIndex{n,T}
    bwt::WaveletMatrix{n,CompactBitVector}
    sentinel::Int
    samples::Vector{T}
    sampled::CompactBitVector
    count::Vector{Int}
end

function restore(index::FMIndex)
    n = length(index)
    text = Vector{UInt8}(n)
    p = index.sentinel
    while n > 0
        p = lfmap(index, p)
        text[n] = index.bwt[p ≥ index.sentinel ? p - 1 : p]
        n -= 1
    end
    return text
end

function count(query, index::FMIndex)
    return length(sa_range(query, index))
end

function locate(query, index::FMIndex)
    return LocationIterator(sa_range(query, index), index)
end

function locateall(query, index::FMIndex)
    iter = locate(query, index)
    locs = Vector{Int}(length(iter))
    for (i, loc) in enumerate(iter)
        locs[i] = loc
    end
    return locs
end

include("index.jl")
include("sa.jl")
include("lociter.jl")

end # module
