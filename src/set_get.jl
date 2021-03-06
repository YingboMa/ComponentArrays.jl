## Field access through these functions to reserve dot-getting for keys
"""
    getaxes(x::ComponentArray)

Access ```.axes``` field of a ```ComponentArray```. This is different than ```axes(x::ComponentArray)```, which
    returns the axes of the contained array.

# Examples

```jldoctest
julia> using ComponentArrays

julia> ax = Axis(a=1:3, b=(4:6, (a=1, b=2:3)))
Axis{(a = 1:3, b = (4:6, (a = 1, b = 2:3)))}()

julia> A = zeros(6,6);

julia> ca = ComponentArray(A, (ax, ax))
6×6 ComponentArray{Tuple{Axis{(a = 1:3, b = (4:6, (a = 1, b = 2:3)))},Axis{(a = 1:3, b = (4:6, (a = 1, b = 2:3)))}},Float64,2,Array{Float64,2}}:
 0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0

julia> getaxes(ca)
(Axis{(a = 1:3, b = (4:6, (a = 1, b = 2:3)))}(), Axis{(a = 1:3, b = (4:6, (a = 1, b = 2:3)))}())
```
"""
@inline getaxes(x::ComponentArray) = getfield(x, :axes)
@inline getaxes(::Type{<:ComponentArray{T,N,A,<:Axes}}) where {T,N,A,Axes} = map(x->x(), (Axes.types...,))

@inline getaxes(x::VarAxes) = getaxes(typeof(x))
@inline getaxes(Ax::Type{<:Axes}) where {Axes<:VarAxes} = map(x->x(), (Ax.types...,))

"""
    getdata(x::ComponentArray)

Access ```.data``` field of a ```ComponentArray```, which contains the array that ```ComponentArray``` wraps.
"""
@inline getdata(x::ComponentArray) = getfield(x, :data)
@inline getdata(x) = x


# Get AbstractAxis index
@inline Base.getindex(::AbstractAxis, idx::FlatIdx) = ComponentIndex(idx)
@inline Base.getindex(ax::AbstractAxis, ::Colon) = ComponentIndex(:, ax)
@inline Base.getindex(::AbstractAxis{IdxMap}, s::Symbol) where IdxMap =
    ComponentIndex(getproperty(IdxMap, s))

# Get ComponentArray index
@inline Base.getindex(x::ComponentArray, idx::FlatIdx...) = Base.maybeview(getdata(x), idx...)
@inline Base.getindex(x::ComponentArray, ::Colon) = @view getdata(x)[:]
@inline Base.getindex(x::ComponentArray, ::Colon...) = x
@inline Base.getindex(x::ComponentArray, idx...) = getindex(x, toval.(idx)...)
@inline Base.getindex(x::ComponentArray, idx::Val...) = _getindex(x, idx...)

# Set ComponentArray index
@inline Base.setindex!(x::ComponentArray, v, idx::FlatIdx...) = setindex!(getdata(x), v, idx...)
@inline Base.setindex!(x::ComponentArray, v, ::Colon) = setindex!(getdata(x), v, :)
@inline Base.setindex!(x::ComponentArray, v, idx...) = setindex!(x, v, toval.(idx)...)
@inline Base.setindex!(x::ComponentArray, v, idx::Val...) = _setindex!(x, v, idx...)


# Property access for CVectors goes through _get/_setindex
@inline Base.getproperty(x::ComponentVector, s::Symbol) = _getindex(x, Val(s))
@inline Base.setproperty!(x::ComponentVector, s::Symbol, v) = _setindex!(x, v, Val(s))


# Generated get and set index methods to do all of the heavy lifting in the type domain
@generated function _getindex(x::ComponentArray, idx...)
    ci = getindex.(getaxes(x), getval.(idx))
    inds = map(i -> i.idx, ci)
    axs = map(i -> i.ax, ci)
    axs = remove_nulls(axs...)
    return :(Base.@_inline_meta; ComponentArray(Base.maybeview(getdata(x), $inds...), $axs...))
end

@generated function _setindex!(x::ComponentArray, v, idx...)
    ci = getindex.(getaxes(x), getval.(idx))
    inds = map(i -> i.idx, ci)
    return :(Base.@_inline_meta; setindex!(getdata(x), v, $inds...))
end
