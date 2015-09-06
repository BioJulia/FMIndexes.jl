using FMIndices
using FactCheck

facts("construct") do
    context("short") do
        seq = [0x00, 0x01, 0x02, 0x03]
        index = FMIndex(seq, 4)
        @fact typeof(index) --> FMIndex{2,UInt8}
    end

    context("long") do
        seq = rand(0x00:0x01, 2^27 + 1)
        index = FMIndex(seq, 2)
        @fact typeof(index) --> FMIndex{1,UInt32}
    end
end

facts("restore") do
    context("examples") do
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

        @pending count([0x01, 0x00], index) --> 0
    end
end

facts("locate/locateall") do
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

    text = open(readall, Pkg.dir("FMIndices", "test", "lorem_ipsum.txt"))
    index = FMIndex(text)

    @fact count("Lorem", index) --> 1
    @fact locateall("Lorem", index) --> [1]
    @fact count("hoge", index) --> 0
    @fact locateall("hoge", index) --> isempty
    for query in ["a", "ex", "non", "Cras", "sollicitudin"]
        locs = linear_search(query)
        @fact count(query, index) --> length(locs)
        @fact locateall(query, index) |> sort --> locs
    end
end
