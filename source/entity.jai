INVALID_ENTITY_HANDLE :: Entity_Handle.{-1, -1};

Entity :: struct {
    using position: Vector2;
    velocity:       Vector2;
    speed:          float;
}

Entity_Handle :: struct {
    index: s32;
    generation: s32;
}

init_entities :: () {
    array_add(*gs.entity.entities, .{});
    array_add(*gs.entity.generations, 0);
}

create_entity :: () -> Entity_Handle {
    using gs.entity;
    result : Entity_Handle;

	if unused_entity_handles.count > 0 {
	    result = pop(*unused_entity_handles);
		generations[result.index] = result.generation;
	} else {
		result.index = xx gs.entity.entities.count;
		result.generation = 0;
		array_add(*entities, .{});
		array_add(*generations, 0);
	}

	array_add(*active_entities, result.index);
	entities[result.index] = .{};

    return result;
}

get_entity :: (handle : Entity_Handle) -> *Entity {
    using gs.entity;
    result := *entities[0];

    if (handle.index < entities.count) {
        stored_generation := generations[handle.index];

        if (stored_generation == handle.generation) {
            result = *entities[handle.index];
        }
    }

    return result;
}

destroy_entity :: (handle: Entity_Handle) {
    using gs.entity;
    if (handle.index > entities.count) return;

    stored_generation := generations[handle.index];
    if (stored_generation != handle.generation) return;

    generations[handle.index] += 1;
    array_add(*unused_entity_handles, .{handle.index, handle.generation + 1});

    // for entity_index, i in active_entities {
    //     if entity_index == handle.index {
    //         // remove
    //         brea
    //     }
    // }
}
