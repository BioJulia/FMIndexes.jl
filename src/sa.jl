# utils about suffix arrays and BWT

function make_sa(seq, σ, T)
    n = length(seq)
    MiB = 1024^2
    if n * sizeof(T) ≤ 512MiB
        sa′ = Vector{Int}(n)
        SuffixArrays.sais(seq, sa′, 0, n, nextpow2(σ), false)
        sa = convert(Vector{T}, sa′)
    else
        path, io = mktemp()
        finalizer(io, io -> begin close(io); rm(path) end)
        sa = Mmap.mmap(io, Vector{T}, (n,))
        SuffixArrays.sais_se(seq, sa, σ)
    end
    return sa
end

function sample_sa{T}(sa::Vector{T}, r)
    n = length(sa)
    samples = Vector{T}(cld(n, r))
    sampled = falses(n)
    i′ = 0
    @assert n ≥ 2
    for i in 1:n
        @assert 0 ≤ sa[i] ≤ n - 1
        if sa[i] % r == 0
            samples[i′+=1] = sa[i]
            sampled[i] = true
        end
    end
    return samples, sampled
end

function bwt(seq, sa)
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
