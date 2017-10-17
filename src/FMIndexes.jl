__precompile__()

module FMIndexes

export
    FMIndex,
    restore,
    count,
    locate,
    locateall

using SuffixArrays
using WaveletMatrices
using IndexableBitVectors
using Humanize

"""
Index for full-text search.

Type parameters:

* `w`: the number of bits required to encode the alphabet
* `T`: the type to represent positions of a sequence
"""
immutable FMIndex{w,T}
    bwt::WaveletMatrix{w,UInt8,SucVector}
    sentinel::Int
    samples::Vector{T}
    sampled::SucVector
    count::Vector{Int}
end

function FMIndex(seq, sa, σ, r)
    wm = WaveletMatrix(make_bwt(seq, sa), log2(Int, σ))
    # sample suffix array
    samples, sampled = sample_sa(sa, r)
    sentinel = findfirst(sa, 0) + 1
    # count characters
    count = count_bytes(seq, σ)
    count[1] = 1  # sentinel '$' is smaller than any character
    cumsum!(count, count)
    return FMIndex(wm, sentinel, samples, SucVector(sampled), count)
end

"""
    FMIndex(seq, σ=256; r=32, program=:SuffixArrays, mmap::Bool=false, opts...)

Build an FM-Index from a sequence `seq`.
The sequence must support `convert(UInt8, seq[i])` for each character and the
alphabet size should be less than or equal to 256. The second parameter, `σ`, is
the alphabet size. The third parameter, `r`, is the interval of sampling values
from a suffix array. If you set it large, you can save the memory footprint but
it requires more time to locate the position.
"""
function FMIndex(seq, σ=256; r=32, program=:SuffixArrays, mmap::Bool=false, opts...)
    T = index_type(length(seq))
    opts = Dict(opts)
    @assert !haskey(opts, :σ) "σ should be passed as the second argument"
    if program === :SuffixArrays
        @assert 1 ≤ σ ≤ typemax(UInt8) + 1
        sa = make_sa(T, seq, σ, mmap)
    elseif program === :psascan || program === :pSAscan
        @assert 1 ≤ σ ≤ typemax(UInt8)
        psascan = get(opts, :psascan, "psascan")
        workdir = get(opts, :workdir, pwd())
        sa = make_sa_pscan(T, seq, psascan, workdir, mmap)
    else
        error("unknown program name: $program")
    end
    return FMIndex(seq, sa, σ, r)
end

"""
    FMIndex(text::String; opts...)

Build an FM-Index from an ASCII text.
"""
function FMIndex(text::String; opts...)
    return FMIndex(convert(Vector{UInt8}, text), 128; opts...)
end

Base.length(index::FMIndex) = length(index.bwt)

function Base.show{w,T}(io::IO, fmindex::FMIndex{w,T})
    println(io, summary(fmindex), ':')
    totalsize = (
        sizeof(fmindex.bwt) +
        sizeof(fmindex.samples) +
        sizeof(fmindex.sampled) +
        sizeof(fmindex.count)
    )
    print("     length: ", length(fmindex), '\n')
    print("  data size: ", datasize(totalsize, style=:bin))
end

"""
Restore the original text from the index.
"""
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

"""
Count the number of occurrences of the given query.
"""
function Base.count(query, index::FMIndex)
    return length(sa_range(query, index))
end

"""
Locate the positions of occurrences of the given query.
This method returns an iterator of positions:

    for pos in locate(query, index)
        # ...
    end
"""
function locate(query, index::FMIndex)
    return LocationIterator(sa_range(query, index), index)
end

"""
Locate the positions of all occurrences of the given query.
"""
function locateall(query, index::FMIndex)
    iter = locate(query, index)
    locs = Vector{Int}(length(iter))
    for (i, loc) in enumerate(iter)
        locs[i] = loc
    end
    return locs
end

include("index.jl")
include("saca.jl")
include("lociter.jl")

end # module
