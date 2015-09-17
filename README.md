# FMIndices

[![Build Status](https://travis-ci.org/BioJulia/FMIndices.jl.svg?branch=master)](https://travis-ci.org/BioJulia/FMIndices.jl)

[FM-index](https://en.wikipedia.org/wiki/FM-index) is a static, compact, and fast index for full-text search.

The index type, `FMIndex{w,T}`, is able to index an arbitrary byte sequence.
`w` is the number of bits required to encode the alphabet of the sequence and `T` is the type of positions of the sequence.


```julia
julia> fmindex = FMIndex("abracadabra");

julia> count("abra", fmindex)  # count the number of occurrences of a query
2

julia> locate("ra", fmindex)
FMIndices.LocationIterator{7,UInt8}(11:12,FMIndices.FMIndex{7,UInt8}(UInt8[0x61,0x72,0x64,0x72,0x63,0x61,0x61,0x61,0x61,0x62,0x62],4,UInt8[0x00],Bool[false,false,true,false,false,false,false,false,false,false,false],[1,1,1,1,1,1,1,1,1,1  …  12,12,12,12,12,12,12,12,12,12]))

julia> for loc in locate("ra", fmindex)  # return the iterator of positions of a query
           println(loc)
       end
10
3

julia> locateall("ra", fmindex)  # return the all positions of a query
2-element Array{Int64,1}:
 10
  3

julia> bytestring(restore(fmindex))  # restore a byte sequence from the index
"abracadabra"

```


## Tips for efficient indexing

The following is a general constructor:

```julia
FMIndex(seq, σ=256; r=32, program=:SuffixArrays, mmap::Bool=false, opts...)
```

`σ` is the size of the alphabet; for example, if the sequence is a DNA sequence, setting `σ` to 4 (four nucleotides) is the best choice in terms of efficiency.
Setting larger `σ` value than necessary is just a waste of query time and index space.

The positions of the sequence are sampled every `r` elements. There is a trade-off between query time and index space about this value: the smaller `r` is, the faster it is to locate positions but the larger the index is.

`program` is used to construct the suffix array of the sequence. The [SuffixArrays.jl](https://github.com/quinnj/SuffixArrays.jl) package is by default, but if you want to create the index for a very long sequence it is recommended to use the [pSAscan](https://www.cs.helsinki.fi/group/pads/pSAscan.html) program.
Also, the `mmap` flag determines wheather the suffix array is stored in a memory-mapped array or not. This flag would be necessary for a long sequence because the temporary suffix array often consumes larger memory space than the index itself (for instance, the suffix array of a sequence of 2^32 length consumes 16GiB RAM).
