# Suffix Array Construction Algorithms

# a wrapper type for a sequence that returns byte-convertible elements
struct ByteSeq{S} <: AbstractVector{UInt8}
    data::S
end
Base.size(seq::ByteSeq) = (length(seq.data),)
@inline Base.getindex(seq::ByteSeq, i::Integer) = UInt8(seq.data[i])

# SuffixArrays.jl: https://github.com/quinnj/SuffixArrays.jl
function make_sa(T, seq, σ, mmap)
    n = length(seq)
    tmp_sa = mmap ? Mmap.mmap(Vector{Int}, n) : Vector{Int}(undef, n)
    SuffixArrays.sais(ByteSeq(seq), tmp_sa, 0, n, nextpow(2, σ), false)
    sa = mmap ? Mmap.mmap(Vector{T}, n) : Vector{T}(undef, n)
    copyto!(sa, tmp_sa)
    return sa
end

# pSAscan: https://www.cs.helsinki.fi/group/pads/pSAscan.html
function make_sa_pscan(T, seq, psascan, workdir, mmap)
    seqpath, io = mktemp(workdir)
    sapath = string(seqpath, ".sa5")
    try
        dump_seq(io, seq)
        run(`$psascan -o $sapath $seqpath`)
        return load_sa(T, sapath, mmap)
    catch
        rethrow()
    finally
        rm(seqpath)
        isfile(sapath) && rm(sapath)
    end
end

function dump_seq(io, seq)
    @inbounds for i in 1:length(seq)
        write(io, convert(UInt8, seq[i]))
    end
    close(io)
end

function load_sa(T, file, mmap)
    # load a 40-bit suffix array generated from psascan
    size = filesize(file)
    @assert size % 5 == 0 "file $file is not 40-bit integers"
    n = div(size, 5)
    sa = mmap ? Mmap.mmap(Vector{T}, n) : Vector{T}(n)
    open(file) do input
        load_sa!(input, sa)
    end
    return sa
end

function load_sa!(input::IO, sa::Vector{T}) where T
    # load a suffix array from the `input` into `sa`
    buf = Vector{UInt8}(undef, 5)
    i = 0
    while !eof(input)
        read!(input, buf)
        value = T(0)
        @inbounds for j in 1:5
            value |= convert(T, buf[j]) << 8 * (j - 1)
        end
        sa[i+=1] = value
    end
    @assert i == length(sa)
    return sa
end


# other utils

function index_type(n)
    n -= 1
    n ≤ typemax(UInt8)  ? UInt8  :
    n ≤ typemax(UInt16) ? UInt16 :
    n ≤ typemax(UInt32) ? UInt32 : UInt64
end

# suffix array sampling
function sample_sa(sa::Vector{T}, r) where T
    n = length(sa)
    samples = Vector{T}(undef, cld(n, r))
    sampled = falses(n)
    i′ = 0
    for i in 1:n
        @assert 0 ≤ sa[i] ≤ n - 1
        if sa[i] % r == 0
            samples[i′+=1] = sa[i]
            sampled[i] = true
        end
    end
    return samples, sampled
end

# Burrows-Wheeler Transform
function make_bwt(seq, sa)
    n = length(seq)
    @assert length(sa) == n
    ret = Vector{UInt8}(undef, n)
    j = 1
    for i in 1:n
        # note that `sa` starts from zero
        p = sa[i]
        if p == 0
            ret[1] = seq[end]
        else
            ret[j+=1] = seq[p]
        end
    end
    return ret
end
