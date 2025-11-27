Entity :: struct {
    using position : Vector2;
    velocity :       Vector2;

    generation: s32;
}

Entity_Handle :: struct {
    index: s32;
    generation: s32;
}

create_entity :: () -> Entity_Handle {
    result : Entity_Handle;

    if (gs.entity.entities.count == 0) array_add(*gs.entity.entities, .{});

	if (gs.entity.unused_entity_handles.count > 0) {
	    result = pop(*gs.entity.unused_entity_handles);
		result.generation += 1;
		gs.entity.entities[result.index].generation = result.generation;
	} else {
	    array_add(*gs.entity.entities, .{});
		result.index = xx gs.entity.entities.count;
	}

    return result;
}

get_entity :: (handle : Entity_Handle) -> *Entity {
    result := *gs.entity.entities[0];
    if (handle.index < gs.entity.entities.count) {
        stored_generation := gs.entity.entities[handle.index].generation;

        if (stored_generation == handle.generation) {
            result = *gs.entity.entities[handle.index];
        }
    }

    return result;
}
