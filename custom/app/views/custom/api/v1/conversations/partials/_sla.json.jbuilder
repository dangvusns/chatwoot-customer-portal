applied_sla = conversation.applied_sla
if applied_sla
  json.applied_sla do
    json.id applied_sla.id
    json.sla_status applied_sla.sla_status
    json.sla_completed_at applied_sla.completed_at&.to_i
    json.sla_frt_due_at applied_sla.first_response_due_at
    json.sla_nrt_due_at applied_sla.next_response_due_at
    json.sla_rt_due_at applied_sla.resolution_due_at
  end
  json.sla_events applied_sla.sla_events.sort_by(&:created_at) do |sla_event|
    json.event_type sla_event.event_type
    json.created_at sla_event.created_at.to_i
  end
else
  json.applied_sla({})
  json.sla_events []
end
