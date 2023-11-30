"The basic type for all Entities."
abstract type Entity end

"Entities that are not composed of other Entities."
abstract type EntityElement <: Entity end

"Entities that are composed of other Entities."
abstract type EntitySet <: Entity end

# TODO perhaps put this elsewhere; it is also referenced in metrics.jl
"Delimeter to use when constructing fully-qualified names."
const NAME_DELIMETER::String = "__"

"Canonical way to turn a Component subtype into a unique string."
subtype_to_string(subtype::Type{<:Component}) = IS.strip_module_name(subtype)

"Canonical way to turn a Component specification/instance into a unique-per-System string."
component_to_qualified_string(
    component_subtype::Type{<:Component},
    component_name::AbstractString,
) = subtype_to_string(component_subtype) * NAME_DELIMETER * component_name
component_to_qualified_string(component::Component) =
    component_to_qualified_string(typeof(component), PSY.get_name(component))

# Generic implementations/generic docstrings for simple functions with many methods
"""
Get the default name for the Entity, constructed automatically from what the Entity
contains. Particularly with complex Entities, this may not always be very concise or
informative, so in these cases constructing the Entity with a custom name is recommended.
"""
function default_name end

"""
Get the name of the Entity. This is either the default name or a custom name passed in at
creation time.
"""
# Override this if you define an Entity subtype with no name field
get_name(e::Entity) = (e.name !== nothing) ? e.name : default_name(e)

"""
Get the components of the System that make up the Entity.
"""
function get_components end

# ComponentEntity
"Entity that wraps a single Component."
struct ComponentEntity <: EntityElement
    component_subtype::Type{<:Component}
    component_name::AbstractString
    name::Union{String, Nothing}
end

# Construction
"""
Make an EntityElement pointing to a Component with the given subtype and name. Optionally
provide a name for the EntityElement.
"""
make_entity(
    component_subtype::Type{<:Component},
    component_name::AbstractString,
    name::Union{String, Nothing} = nothing,
) = ComponentEntity(component_subtype, component_name, name)
"""
Construct an EntityElement from a Component reference, pointing to Components in any System
with the given Component's subtype and name.
"""
make_entity(component_ref::Component, name::Union{String, Nothing} = nothing) =
    make_entity(typeof(component_ref), get_name(component_ref), name)

# Naming
default_name(e::ComponentEntity) =
    component_to_qualified_string(e.component_subtype, e.component_name)

# Contents
function get_components(e::ComponentEntity, sys::PSY.System)::Vector{Component}
    com = get_component(e.component_subtype, sys, e.component_name)
    return com === nothing ? [] : [com]
end

# ListEntitySet
"EntitySet represented by a list of other Entities."
struct ListEntitySet <: EntitySet
    # Using tuples internally for immutability => `==` is automatically well-behaved
    content::Tuple{Vararg{Entity}}
    name::Union{String, Nothing}
end

# Construction
"""
Make an EntitySet pointing to a list of sub-entities. Optionally provide a name for the
EntitySet.
"""
# name needs to be a kwarg to disambiguate from content
make_entity(content::Entity...; name::Union{String, Nothing} = nothing) =
    ListEntitySet(content, name)

# Naming
default_name(e::ListEntitySet) = "[$(join(get_name.(e.content), ", "))]"

# Contents
function get_subentities(e::ListEntitySet, sys::PSY.System)
    return e.content
end

function get_components(e::ListEntitySet, sys::PSY.System)
    sub_components = Iterators.map(x -> get_components(x, sys), e.content)
    return IS.FlattenIteratorWrapper(Component, sub_components)
end

# SubtypeEntitySet
"EntitySet represented by a subtype of Component."
struct SubtypeEntitySet <: EntitySet
    component_subtype::Type{<:Component}
    name::Union{String, Nothing}
end

# Construction
"""
Make a SubtypeEntitySet from a subtype of Component. Optionally provide a name for the
EntitySet.
"""
# name needs to be a kwarg to disambiguate from ComponentEntity's make_entity
make_entity(component_subtype::Type{<:Component}; name::Union{String, Nothing} = nothing) =
    SubtypeEntitySet(component_subtype, name)

# Naming
default_name(e::SubtypeEntitySet) = subtype_to_string(e.component_subtype)

# Contents
function get_subentities(e::SubtypeEntitySet, sys::PSY.System)
    # Lazily construct ComponentEntitys from the Components
    return Iterators.map(make_entity, get_components(e, sys))
end

function get_components(e::SubtypeEntitySet, sys::PSY.System)
    return get_components(e.component_subtype, sys)
end

# TopologyEntitySet
"EntitySet represented by an AggregationTopology and a subtype of Component."
struct TopologyEntitySet <: EntitySet
    topology_subtype::Type{<:PSY.AggregationTopology}
    topology_name::AbstractString
    component_subtype::Type{<:Component}
    name::Union{String, Nothing}
end

# Construction
"""
Make a TopologyEntitySet from an AggregationTopology and a subtype of Component. Optionally
provide a name for the EntitySet.
"""
make_entity(
    topology_subtype::Type{<:PSY.AggregationTopology},
    topology_name::AbstractString,
    component_subtype::Type{<:Component},
    name::Union{String, Nothing} = nothing,
) = TopologyEntitySet(
    topology_subtype,
    topology_name,
    component_subtype,
    name,
)

# Naming
default_name(e::TopologyEntitySet) =
    component_to_qualified_string(e.topology_subtype, e.topology_name) * NAME_DELIMETER *
    subtype_to_string(e.component_subtype)

# Contents
function get_subentities(e::TopologyEntitySet, sys::PSY.System)
    return Iterators.map(make_entity, get_components(e, sys))
end

function get_components(e::TopologyEntitySet, sys::PSY.System)
    agg_topology = get_component(e.topology_subtype, sys, e.topology_name)
    return PSY.get_components_in_aggregation_topology(
        e.component_subtype,
        sys,
        agg_topology,
    )
end

# FilterEntitySet
"EntitySet represented by a filter function and a subtype of Component."
struct FilterEntitySet <: EntitySet
    filter_fn::Function
    component_subtype::Type{<:Component}
    name::Union{String, Nothing}
end

# Construction
"""
Make a FilterEntitySet from a filter function and a subtype of Component. Optionally provide
a name for the EntitySet. The filter function must accept instances of component_subtype as
a sole argument and return a Bool.
"""
function make_entity(
    filter_fn::Function,
    component_subtype::Type{<:Component},
    name::Union{String, Nothing} = nothing,
)
    # Try to catch inappropriate filter functions
    hasmethod(filter_fn, Tuple{component_subtype}) || throw(
        ArgumentError(
            "filter function $filter_fn does not have a method that accepts $(subtype_to_string(component_subtype)).",
        ),
    )
    # TODO it would be nice to have more rigorous checks on filter_fn here: check that the
    # return type is a Bool and check whether a filter_fn without parameter type annotations
    # can in fact be called on the given subtype (e.g., filter_fn = (x -> x+1 == 0) should
    # fail). Core.compiler.return_type does not seem to be stable enough to rely on. The
    # IsDef.jl library looks interesting.
    return FilterEntitySet(filter_fn, component_subtype, name)
end

# Naming
default_name(e::FilterEntitySet) =
    string(e.filter_fn) * NAME_DELIMETER * subtype_to_string(e.component_subtype)

# Contents
function get_subentities(e::FilterEntitySet, sys::PSY.System)
    return Iterators.map(make_entity, get_components(e, sys))
end

function get_components(e::FilterEntitySet, sys::PSY.System)
    return get_components(e.filter_fn, e.component_subtype, sys)
end
