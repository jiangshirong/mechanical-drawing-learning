import json
from pathlib import Path

app = Path(__file__).resolve().parents[1] / '机械制图学习'
def read(name):
    return json.loads((app / 'qa' / name).read_text(encoding='utf-8'))

before, after = read('render-before.json'), read('render-after.json')
b = {row['name']: row for row in before['samples']}
a = {row['name']: row for row in after['samples']}
checks = {
    'msaa_4x': after['msaa'] == 2,
    'same_benchmark_camera': before['camera'] == after['camera'],
    'same_benchmark_viewport': before['viewport_size'] == after['viewport_size'],
    'point_reuses_geometry': a['thirty_point_updates']['same_helpers'],
    'point_reuses_marker': a['thirty_point_updates']['same_marker'],
    'point_update_faster': a['thirty_point_updates']['total_ms'] < b['thirty_point_updates']['total_ms'],
    'idle_has_no_paper_redraw': a['free_idle']['paper_redraws'] == a['guide_final_idle']['paper_redraws'] == 0,
    'idle_stops_continuous_root_render': a['free_idle']['rendered_frames'] < 10 and a['guide_final_idle']['rendered_frames'] < 10,
    'rotation_renders_each_frame': a['free_rotate']['rendered_frames'] == 90,
    'animation_does_not_redraw_unchanged_paper': a['guide_animation']['paper_redraws'] <= 1,
    'no_geometry_rebuild_during_observation': all(row.get('helper_rebuilds', 0) == 0 for row in a.values()),
    'large_window_native_resolution': after['large_window']['native_resolution'],
    'large_window_point_input': after['large_window']['point_input_scaled'],
    'offscreen_qa': before['offscreen'] and after['offscreen'],
    'benchmark_processes_exited': not before['remaining'] and not after['remaining'],
}
assert all(checks.values()), checks
report = {
    'checks': checks,
    'point_updates_30_ms': {'before': b['thirty_point_updates']['total_ms'], 'after': a['thirty_point_updates']['total_ms']},
    'measurement_boundary': 'Same-machine offscreen test. Point timings measure code updates, not total frame time. TIME_PROCESS is delayed and is not used as evidence for per-frame CPU improvement. Idle process intervals are not rendered FPS. Root render counts include a 100 ms activity grace period; the 3D viewport updates only on changes.',
    'large_window': after['large_window'],
    'visual_review': ['render-before-guide.png', 'render-after-guide.png', 'render-quality-slope.png', 'render-quality-base.png', 'render-quality-bracket.png', 'render-quality-section.png'],
    'rendering': {'edge_width_px': 1.4, 'view_bias_mm': 0.08, 'depth_test': True, 'msaa_samples': 4, 'resolution_density_limit': 2},
    'remaining_test_processes': [],
    'early_failed_attempts': [{'pid': 42252, 'reason': 'Script parse error fixed before final runs', 'normal_close_requested': True, 'exited': True}, {'pid': 11492, 'reason': 'QA screenshot awaited an idle frame; fixed by explicitly requesting a draw', 'normal_close_requested': True, 'normal_close_result': False, 'timeout_cleanup_scoped_to_owned_pid': True, 'exited': True}],
}
(app / 'qa' / 'render-optimization-check.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
final = read('最终核验.json')
final['render_optimization'] = report
(app / 'qa' / '最终核验.json').write_text(json.dumps(final, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'checks_passed': sum(checks.values()), 'total': len(checks), 'point_updates_30_ms': report['point_updates_30_ms']}, ensure_ascii=False))
