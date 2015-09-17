# utils about suffix arrays and BWT

function index_type(n)
    n ≤ typemax(UInt8)  ? UInt8  :
    n ≤ typemax(UInt16) ? UInt16 :
    n ≤ typemax(UInt32) ? UInt32 : UInt64
end

function make_sa(T, seq, σ, mmap)
    n = length(seq)
    tmp_sa = mmap ? Mmap.mmap(Vector{Int}, n) : Vector{Int}(n)
    SuffixArrays.sais(seq, tmp_sa, 0, n, nextpow2(σ), false)
    sa = mmap ? Mmap.mmap(Vector{T}, n) : Vector{T}(n)
    copy!(sa, tmp_sa)
    return sa
end

function sample_sa{T}(sa::Vector{T}, r)
    n = length(sa)
    samples = Vector{T}(cld(n, r))
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

function make_bwt(seq, sa)
    n = length(seq)
    @assert length(sa) == n
    ret = Vector{UInt8}(n)
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


# pSAscan
# -------
#
# https://www.cs.helsinki.fi/group/pads/pSAscan.html

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

function load_sa!{T}(input::IO, sa::Vector{T})
    # load a suffix array from the `input` into `sa`
    buf = Vector{UInt8}(5)
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
