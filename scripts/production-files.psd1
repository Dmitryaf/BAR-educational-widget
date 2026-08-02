@{
    EntryPoint = 'bar_learning_coach.lua'
    LegacyEntryPoints = @(
        'bar_learning_coach_debug.lua'
    )
    Helpers = @(
        'coach_presentation.lua'
        'energy_stall.lua'
        'energy_stall_recommendation.lua'
        'history_buffer.lua'
        'opening_adapter.lua'
        'opening_context.lua'
        'opening_progress.lua'
        'opening_tracker.lua'
        'snapshot_collector.lua'
    )
}
