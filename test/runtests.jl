using FMIndexes
using Combinatorics
using Base.Test

srand(12345)

# simple DNA sequence type
@enum Nuc A C G T
type DNASeq
    data::Vector{Nuc}
end
Base.getindex(seq::DNASeq, i::Integer) = seq.data[i]
Base.length(seq::DNASeq) = length(seq.data)
Base.endof(seq::DNASeq)  = length(seq.data)


@testset "construct" begin
    @testset "one" begin
        σ = 2
        seq = [0x00]
        index = FMIndex(seq, σ)
        @test typeof(index) == FMIndex{1,UInt8}
    end

    @testset "short" begin
        σ = 4
        seq = [0x00, 0x01, 0x02, 0x03]
        index = FMIndex(seq, σ)
        @test typeof(index) == FMIndex{2,UInt8}
    end

    @testset "long" begin
        σ = 2
        seq = rand(0x00:0x01, 2^24)
        index = FMIndex(seq, σ)
        @test typeof(index) == FMIndex{1,UInt32}
    end

    @testset "dna" begin
        σ = 4
        seq = DNASeq([A, C, G, T, A, T])
        index = FMIndex(seq, σ)
        @test typeof(index) == FMIndex{2,UInt8}
    end

    @testset "boundaries" begin
        σ = 4
        # 8 bits
        n = 2^8
        seq = rand(0x00:0x03, n)
        index = FMIndex(seq, σ)
        @test typeof(index) == FMIndex{2,UInt8}
        # 16 bits
        n = 2^16
        seq = rand(0x00:0x03, n)
        index = FMIndex(seq, σ)
        @test typeof(index) == FMIndex{2,UInt16}
        # 32 bits
        # too long to test!
    end

    @testset "mmap" begin
        σ = 4
        seq = rand(0x00:0x03, 2^10)
        index = FMIndex(seq, σ, mmap=true)
        @test typeof(index) == FMIndex{2,UInt16}
    end

    @testset "use pSAscan" begin
        σ = 4
        seq = rand(0x00:0x03, 2^24)
        if haskey(ENV, "PSASCAN")
            index = FMIndex(seq, σ, program=:psascan, psascan=ENV["PSASCAN"], mmap=true)
            @test typeof(index) == FMIndex{2,UInt32}
        else
            info("Skipped a test")
            #@pending typeof(index) --> FMIndex{2,UInt32}
        end
    end
end

@testset "restore" begin
    @testset "examples" begin
        σ = 2
        seq = [0x01]
        index = FMIndex(seq, σ)
        @test restore(index) == seq

        σ = 2
        seq = [0x00, 0x00, 0x01, 0x01]
        index = FMIndex(seq, σ)
        @test restore(index) == seq

        seq = [0x01, 0x01, 0x00, 0x00]
        index = FMIndex(seq, σ)
        @test restore(index) == seq

        σ = 128
        seq = Vector{UInt8}("abracadabra")
        index = FMIndex(seq, σ)
        @test restore(index) == seq
    end

    @testset "dna" begin
        σ = 4
        seq = DNASeq([A, C, G, T, A, T])
        index = FMIndex(seq, σ)
        @test restore(index) == [0x00, 0x01, 0x02, 0x03, 0x0, 0x03]
    end

    @testset "random" begin
        σ = 128
        for n in [2, 15, 100], _ in 1:100
            seq = randstring(n)
            index = FMIndex(Vector{UInt8}(seq), σ)
            @test restore(index) == Vector{UInt8}(seq)
        end
    end
end

@testset "count" begin
    @testset "[0x00]" begin
        σ = 2
        index = FMIndex([0x00], σ)
        @test count([0x00], index) == 1
        @test count([0x01], index) == 0
    end

    @testset "\"abracadabra\"" begin
        σ = 128
        seq = Vector{UInt8}("abracadabra")
        index = FMIndex(seq, σ)

        @test count("a", index) == 5
        @test count("ab", index) == 2
        @test count("abr", index) == 2
        @test count("abra", index) == 2
        @test count("abrac", index) == 1

        @test count("d", index) == 1
        @test count("da", index) == 1
        @test count("dab", index) == 1

        @test count("r", index) == 2
        @test count("ra", index) == 2
        @test count("rac", index) == 1

        # not existing
        @test count("x", index) == 0
        @test count("ax", index) == 0
        @test count("aa", index) == 0
        @test count("aaa", index) == 0
        @test count("braa", index) == 0
    end

    @testset "[0x00, 0x00, 0x01, 0x01]" begin
        σ = 2
        seq = [0x00, 0x00, 0x01, 0x01]
        index = FMIndex(seq, σ)

        @test count([0x00], index) == 2
        @test count([0x00, 0x00], index) == 1
        @test count([0x00, 0x00, 0x01], index) == 1
        @test count([0x00, 0x01, 0x01], index) == 1
        @test count([0x00, 0x00, 0x01, 0x01], index) == 1

        @test count([0x01], index) == 2
        @test count([0x01, 0x01], index) == 1

        @test count([0x01, 0x00], index) == 0
        @test count([0x01, 0x01, 0x00], index) == 0
        @test count([0x00, 0x01, 0x01, 0x00], index) == 0
        @test count([0x01, 0x01, 0x00, 0x00], index) == 0
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

@testset "locate/locateall" begin
    @testset "[0x00]" begin
        σ = 2
        index = FMIndex([0x00], σ)
        @test locateall([0x00], index) == [1]
        @test isempty(locateall([0x01], index))
    end

    @testset "\"abracadabra\"" begin
        σ = 128
        seq = Vector{UInt8}("abracadabra")
        index = FMIndex(seq, σ)

        @test locate("a", index) |> collect |> sort == [1, 4, 6, 8, 11]

        @test locateall("a", index) |> sort == [1, 4, 6, 8, 11]
        @test locateall("ab", index) |> sort == [1, 8]
        @test locateall("abr", index) |> sort == [1, 8]
        @test locateall("abra", index) |> sort == [1, 8]
        @test locateall("abrac", index) |> sort == [1]

        @test locateall("d", index) |> sort == [7]
        @test locateall("da", index) |> sort == [7]
        @test locateall("dab", index) |> sort == [7]

        @test locateall("r", index) |> sort == [3, 10]
        @test locateall("ra", index) |> sort == [3, 10]
        @test locateall("rac", index) |> sort == [3]

        @test isempty(locate("x", index))

        @test isempty(locateall("x", index))
        @test isempty(locateall("ax", index))
        @test isempty(locateall("aa", index))
        @test isempty(locateall("aaa", index))
        @test isempty(locateall("braa", index))
    end

    @testset "random" begin
        σ = 4
        seq = rand(0x00:0x03, 10_000)
        index = FMIndex(seq, σ)
        for m in [1, 2, 3, 5, 10]
            query = rand(0x00:0x03, m)
            @test locateall(query, index) |> sort == linear_search(query, seq)
        end
    end

    @testset "boundaries" begin
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
                    @test locateall(query, index) |> sort == linear_search(query, seq)
                end
            end
        end
    end
end

@testset "full-text search" begin
    function linear_search(query)
        locs = Int[]
        loc = 0
        while (loc = searchindex(text, Vector{UInt8}(query), loc + 1)) > 0
            push!(locs, loc)
        end
        return locs
    end

    text = open(read, joinpath(dirname(@__FILE__), "lorem_ipsum.txt"))
    index = FMIndex(text, r=2)

    @test count("Lorem", index) == 1
    @test locateall("Lorem", index) == [1]
    @test count("hoge", index) == 0
    @test isempty(locateall("hoge", index))
    for query in ["a", ".",
                  "ex", "In",
                  "non", "Sed",
                  "odio", "Cras",
                  "sollicitudin"]
        locs = linear_search(query)
        @test count(query, index) == length(locs)
        @test locateall(query, index) |> sort == locs
    end

    @test String(restore(index)) == String(text)
end
