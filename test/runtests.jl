using FMIndexes
using FactCheck

srand(12345)

# simple DNA sequence type
@enum Nuc A C G T
type DNASeq
    data::Vector{Nuc}
end
Base.getindex(seq::DNASeq, i::Integer) = seq.data[i]
Base.length(seq::DNASeq) = length(seq.data)
Base.endof(seq::DNASeq)  = length(seq.data)


facts("construct") do
    context("one") do
        σ = 2
        seq = [0x00]
        index = FMIndex(seq, σ)
        @fact typeof(index) --> FMIndex{1,UInt8}
    end

    context("short") do
        σ = 4
        seq = [0x00, 0x01, 0x02, 0x03]
        index = FMIndex(seq, σ)
        @fact typeof(index) --> FMIndex{2,UInt8}
    end

    context("long") do
        σ = 2
        seq = rand(0x00:0x01, 2^24)
        index = FMIndex(seq, σ)
        @fact typeof(index) --> FMIndex{1,UInt32}
    end

    context("dna") do
        σ = 4
        seq = DNASeq([A, C, G, T, A, T])
        index = FMIndex(seq, σ)
        @fact typeof(index) --> FMIndex{2,UInt8}
    end

    context("boundaries") do
        σ = 4
        # 8 bits
        n = 2^8
        seq = rand(0x00:0x03, n)
        index = FMIndex(seq, σ)
        @fact typeof(index) --> FMIndex{2,UInt8}
        # 16 bits
        n = 2^16
        seq = rand(0x00:0x03, n)
        index = FMIndex(seq, σ)
        @fact typeof(index) --> FMIndex{2,UInt16}
        # 32 bits
        # too long to test!
    end

    context("mmap") do
        σ = 4
        seq = rand(0x00:0x03, 2^10)
        index = FMIndex(seq, σ, mmap=true)
        @fact typeof(index) --> FMIndex{2,UInt16}
    end

    context("use pSAscan") do
        σ = 4
        seq = rand(0x00:0x03, 2^24)
        if haskey(ENV, "PSASCAN")
            index = FMIndex(seq, σ, program=:psascan, psascan=ENV["PSASCAN"], mmap=true)
            @fact typeof(index) --> FMIndex{2,UInt32}
        else
            @pending typeof(index) --> FMIndex{2,UInt32}
        end
    end
end

facts("restore") do
    context("examples") do
        σ = 2
        seq = [0x01]
        index = FMIndex(seq, σ)
        @fact restore(index) --> seq

        σ = 2
        seq = [0x00, 0x00, 0x01, 0x01]
        index = FMIndex(seq, σ)
        @fact restore(index) --> seq

        seq = [0x01, 0x01, 0x00, 0x00]
        index = FMIndex(seq, σ)
        @fact restore(index) --> seq

        σ = 128
        seq = "abracadabra".data
        index = FMIndex(seq, σ)
        @fact restore(index) --> seq
    end

    context("dna") do
        σ = 4
        seq = DNASeq([A, C, G, T, A, T])
        index = FMIndex(seq, σ)
        @fact restore(index) --> [0x00, 0x01, 0x02, 0x03, 0x0, 0x03]
    end

    context("random") do
        σ = 128
        for n in [2, 15, 100], _ in 1:100
            seq = randstring(n)
            index = FMIndex(seq.data, σ)
            @fact restore(index) --> seq.data
        end
    end
end

facts("count") do
    context("[0x00]") do
        σ = 2
        index = FMIndex([0x00], σ)
        @fact count([0x00], index) --> 1
        @fact count([0x01], index) --> 0
    end

    context("\"abracadabra\"") do
        σ = 128
        seq = "abracadabra".data
        index = FMIndex(seq, σ)

        @fact count("a", index) --> 5
        @fact count("ab", index) --> 2
        @fact count("abr", index) --> 2
        @fact count("abra", index) --> 2
        @fact count("abrac", index) --> 1

        @fact count("d", index) --> 1
        @fact count("da", index) --> 1
        @fact count("dab", index) --> 1

        @fact count("r", index) --> 2
        @fact count("ra", index) --> 2
        @fact count("rac", index) --> 1

        # not existing
        @fact count("x", index) --> 0
        @fact count("ax", index) --> 0
        @fact count("aa", index) --> 0
        @fact count("aaa", index) --> 0
        @fact count("braa", index) --> 0
    end

    context("[0x00, 0x00, 0x01, 0x01]") do
        σ = 2
        seq = [0x00, 0x00, 0x01, 0x01]
        index = FMIndex(seq, σ)

        @fact count([0x00], index) --> 2
        @fact count([0x00, 0x00], index) --> 1
        @fact count([0x00, 0x00, 0x01], index) --> 1
        @fact count([0x00, 0x01, 0x01], index) --> 1
        @fact count([0x00, 0x00, 0x01, 0x01], index) --> 1

        @fact count([0x01], index) --> 2
        @fact count([0x01, 0x01], index) --> 1

        @fact count([0x01, 0x00], index) --> 0
        @fact count([0x01, 0x01, 0x00], index) --> 0
        @fact count([0x00, 0x01, 0x01, 0x00], index) --> 0
        @fact count([0x01, 0x01, 0x00, 0x00], index) --> 0
    end
end

function linear_search(query, seq)
    locs = Int[]
    for i in 1:endof(seq)-length(query)+1
        j = 1
        while j ≤ length(query) && query[j] == seq[i+j-1]
            j += 1
        end
        if j > length(query)
            push!(locs, i)
        end
    end
    return locs
end

facts("locate/locateall") do
    context("[0x00]") do
        σ = 2
        index = FMIndex([0x00], σ)
        @fact locateall([0x00], index) --> [1]
        @fact locateall([0x01], index) --> isempty
    end

    context("\"abracadabra\"") do
        σ = 128
        seq = "abracadabra".data
        index = FMIndex(seq, σ)

        @fact locate("a", index) |> collect |> sort --> [1, 4, 6, 8, 11]

        @fact locateall("a", index) |> sort --> [1, 4, 6, 8, 11]
        @fact locateall("ab", index) |> sort --> [1, 8]
        @fact locateall("abr", index) |> sort --> [1, 8]
        @fact locateall("abra", index) |> sort --> [1, 8]
        @fact locateall("abrac", index) |> sort --> [1]

        @fact locateall("d", index) |> sort --> [7]
        @fact locateall("da", index) |> sort --> [7]
        @fact locateall("dab", index) |> sort --> [7]

        @fact locateall("r", index) |> sort --> [3, 10]
        @fact locateall("ra", index) |> sort --> [3, 10]
        @fact locateall("rac", index) |> sort --> [3]

        @fact locate("x", index) --> isempty

        @fact locateall("x", index) --> isempty
        @fact locateall("ax", index) --> isempty
        @fact locateall("aa", index) --> isempty
        @fact locateall("aaa", index) --> isempty
        @fact locateall("braa", index) --> isempty
    end

    context("random") do
        σ = 4
        seq = rand(0x00:0x03, 10_000)
        index = FMIndex(seq, σ)
        for m in [1, 2, 3, 5, 10]
            query = rand(0x00:0x03, m)
            @fact locateall(query, index) |> sort --> linear_search(query, seq)
        end
    end

    context("boundaries") do
        σ = 4
        for n in [2^8, 2^16]
            seq = rand(0x00:0x03, n)
            index = FMIndex(seq, σ)
            for set in ([0x00],
                        [0x03],
                        [0x00, 0x00],
                        [0x00, 0x01],
                        [0x02, 0x03],
                        [0x00, 0x01, 0x02],
                        [0x01, 0x02, 0x03],
                        [0x00, 0x01, 0x02, 0x03])
                for query in permutations(set)
                    @fact locateall(query, index) |> sort --> linear_search(query, seq)
                end
            end
        end
    end
end

facts("full-text search") do
    function linear_search(query)
        locs = Int[]
        loc = 0
        while (loc = searchindex(text, query, loc + 1)) > 0
            push!(locs, loc)
        end
        return locs
    end

    text = open(readall, Pkg.dir("FMIndexes", "test", "lorem_ipsum.txt"))
    index = FMIndex(text, r=2)

    @fact count("Lorem", index) --> 1
    @fact locateall("Lorem", index) --> [1]
    @fact count("hoge", index) --> 0
    @fact locateall("hoge", index) --> isempty
    for query in ["a", ".",
                  "ex", "In",
                  "non", "Sed",
                  "odio", "Cras",
                  "sollicitudin"]
        locs = linear_search(query)
        @fact count(query, index) --> length(locs)
        @fact locateall(query, index) |> sort --> locs
    end

    @fact bytestring(restore(index)) --> text
end
