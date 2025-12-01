JMAC_Event_Type :: enum u32 {
    INVALID;
    GAME_START;
}

JMAC_Event_Callback_Func :: #type (event: JMAC_Event);

JMAC_Event_Payload_Empty :: struct {}

JMAC_Event_Payload :: struct {
    union {
        empty:              JMAC_Event_Payload_Empty;
    }
}

JMAC_Event :: struct {
    type:           JMAC_Event_Type;
    payload:        JMAC_Event_Payload;
    debug_message:  string;
}

event_type_subscribe :: (type: JMAC_Event_Type, cb: JMAC_Event_Callback_Func) {
    using gs.event;
    subscribers_for_type := inline table_find_pointer(*subscribers, type);
    if subscribers_for_type == null {
        empty: [..]JMAC_Event_Callback_Func;
        subscribers_for_type = table_add(*subscribers, type, empty);
    }
    array_add(subscribers_for_type, cb);
}

event_enqueue :: inline (event: JMAC_Event) { array_add(*gs.event.queue, event); }

event_update :: () {
    if queue.count <= 0 return;

    event := gs.event.queue[0];
    array_ordered_remove_by_index(*gs.event.queue, 0);
    if event.debug_message log("%", event.debug_message);
    success, subscribers := table_find(*gs.event.subscribers, event.type);
    if success for subscribers it(event);
}
