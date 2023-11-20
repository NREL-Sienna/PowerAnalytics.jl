"The basic type for all Entities."
abstract type Entity end

"Entities that are not composed of other Entities."
abstract type EntityElement <: Entity end

"Entities that are composed of other Entities."
abstract type EntitySet <: Entity end

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

# Generic docstrings for simple functions with many methods
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

# Naming
default_name(e::ComponentEntity) =
    component_to_qualified_string(e.component_subtype, e.component_name)

# Contents
function get_components(e::ComponentEntity, sys::PSY.System)::Vector{Component}
    com = get_component(e.component_subtype, sys, e.component_name)
    return com === nothing ? [] : [com]
end

# ListEntitySet
"EntitySet represented by a list of other Entities"
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
