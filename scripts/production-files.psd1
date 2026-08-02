@{
    EntryPoints = @(
        'bar_replay_coach.lua'
        'bar_learning_coach.lua'
    )
    LegacyEntryPoints = @(
        'bar_learning_coach_debug.lua'
    )
    Helpers = @(
        'coach_presentation.lua'
        'energy_stall.lua'
        'energy_stall_recommendation.lua'
        'episode_aggregator.lua'
        'history_buffer.lua'
        'issue_ranker.lua'
        'opening_adapter.lua'
        'opening_context.lua'
        'opening_progress.lua'
        'opening_tracker.lua'
        'replay_context.lua'
        'replay_observation.lua'
        'replay_opening_collector.lua'
        'replay_report.lua'
        'replay_report_presentation.lua'
        'replay_session.lua'
        'snapshot_collector.lua'
        'training_task_selector.lua'
    )
}
