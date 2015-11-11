function log2(::Type{Int}, x::Integer)
    return 64 - leading_zeros(convert(UInt64, x-1))
end

function count_bytes(seq, σ)
    count = zeros(Int, σ + 1)
    for i in 1:length(seq)
        count[convert(UInt8,seq[i])+2] += 1
    end
    resize!(count, σ)
    return count
end

# LF-mapping
function lfmap(index::FMIndex, i)
    if i == index.sentinel
        return 1
    elseif i > index.sentinel
        i -= 1
    end
    char = index.bwt[i]
    @inbounds return index.count[char+1] + rank(char, index.bwt, i)
end

function sa_range(query, index::FMIndex)
    sa_range(query, index::FMIndex, 1:(length(index)+1))
end

function sa_range(query, index::FMIndex, init_range::UnitRange{Int})
    sp, ep = init_range.start, init_range.stop
    # backward search
    i = length(query)
    while sp ≤ ep && i ≥ 1
        char = convert(UInt8, query[i])
        c = index.count[char+1]
        sp = c + rank(char, index.bwt, (sp > index.sentinel ? sp - 1 : sp) - 1) + 1
        ep = c + rank(char, index.bwt, (ep > index.sentinel ? ep - 1 : ep))
        i -= 1
    end
    return sp:ep
end

@inline function sa_range(char::UInt8, index::FMIndex, range::UnitRange{Int})
    sp, ep = range.start, range.stop
    c = index.count[char+1]
    sp = c + rank(char, index.bwt, (sp > index.sentinel ? sp - 1 : sp) - 1) + 1
    ep = c + rank(char, index.bwt, (ep > index.sentinel ? ep - 1 : ep))
    return sp:ep
end

function sa_value(i::Int, index::FMIndex)
    if i == 1
        # point to the sentinel '$'
        return length(index) + 1
    end
    d = 0
    @inbounds while !index.sampled[i-1]
        i = lfmap(index, i)
        d += 1
    end
    return index.samples[rank1(index.sampled, i - 1)] + d
end

sa_value(i::Integer, index::FMIndex) = sa_value(Int(i), index)
