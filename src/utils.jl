"""
    fastindices(i...)

Wrap ```ComponentArray``` symbolic indices in ```Val```s for type-stable indexing.

# Examples
```julia-repl
julia> using ComponentArrays, BenchmarkTools

julia> ca = ComponentArray(a=1, b=[2, 1, 4], c=(a=2, b=[1, 2]))
ComponentArray{Float64}(a = 1.0, b = [2.0, 1.0, 4.0], c = (a = 2.0, b = [1.0, 2.0]))

julia> ca2 = ca .* ca'
7×7 ComponentArray{Tuple{Axis{(a = 1, b = 2:4, c = (5:7, (a = 1, b = 2:3)))},Axis{(a = 1, b = 2:4, c = (5:7, (a = 1, b = 
2:3)))}},Float64,2,Array{Float64,2}}:
 1.0  2.0  1.0   4.0  2.0  1.0  2.0
 2.0  4.0  2.0   8.0  4.0  2.0  4.0
 1.0  2.0  1.0   4.0  2.0  1.0  2.0
 4.0  8.0  4.0  16.0  8.0  4.0  8.0
 2.0  4.0  2.0   8.0  4.0  2.0  4.0
 1.0  2.0  1.0   4.0  2.0  1.0  2.0
 2.0  4.0  2.0   8.0  4.0  2.0  4.0

julia> _a, _b, _c = fastindices(:a, :b, :c)
(Val{:a}(), Val{:b}(), Val{:c}())

julia> @btime \$ca2[:c,:c];
  12.199 μs (2 allocations: 80 bytes)

julia> @btime \$ca2[\$_c, \$_c];
  14.728 ns (2 allocations: 80 bytes)
```
"""
fastindices(i...) = toval.(i)
fastindices(i::Tuple) = toval.(i)


# Make a Val if input isn't already one
toval(x::Val) = x
toval(x) = Val(x)

# Get value from Val type
getval(::Val{x}) where x = x
getval(::Type{Val{x}}) where x = x

# Split an array up into partitions where the Ns are partition sizes on each dimension
partition(A) = A
function partition(A, N; dim=1)
    first_inds = ntuple(x->:, dim-1)
    last_inds = ntuple(x->:, max(ndims(A)-dim, 0))
    return [view(A, first_inds..., i-N+1:i, last_inds...) for i in N:N:size(A)[dim]]
end
function partition(A, N1, N2, args...)
    N = (N1, N2, args...)
    part_A = partition(A, N[end], dim=length(N))
    for i in length(N)-1:-1:1
        part_A = vcat(partition.(part_A, N[i], dim=i)...)
    end
    return reshape(part_A, div.(size(A), N))
end

# Faster filtering of tuples by type
filter_by_type(::Type{T}, args...) where T = filter_by_type(T, (), args...)
filter_by_type(::Type{T}, part::Tuple) where T = part
filter_by_type(::Type{T}, part::Tuple, ax, args...) where T = filter_by_type(T, part, args...)
filter_by_type(::Type{T}, part::Tuple, ax::T, args...) where T = filter_by_type(T, (part..., ax), args...)

# Flat length of an arbitrarily nested named tuple
recursive_length(x) = length(x)
recursive_length(a::AbstractVector{N}) where N<:Number = length(a)
recursive_length(a::AbstractVector) = recursive_length.(a) |> sum
recursive_length(nt::NamedTuple) = values(nt) .|> recursive_length |> sum
recursive_length(::Missing) = 1