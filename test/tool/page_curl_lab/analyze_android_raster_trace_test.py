import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[3] / 'tool/page_curl_lab/analyze_android_raster_trace.py'
spec = importlib.util.spec_from_file_location('raster_trace', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def event(time, payload, thread=11, process=7):
    return f'worker-{thread} ({process}) [000] ..... {time:.6f}: {payload}'


class RasterTraceTest(unittest.TestCase):
    def test_separates_cpu_from_nested_waits_and_ignores_other_processes(self):
        report = module.analyze([
            event(1, 'tracing_mark_write: B|7|GPURasterizer::Draw'),
            event(1.001, 'sched_switch: prev_pid=0 next_pid=11', process=0),
            event(1.002, 'tracing_mark_write: B|7|QueuePresentKHR'),
            event(1.003, 'tracing_mark_write: B|7|queueBuffer'),
            event(1.004, 'tracing_mark_write: B|7|waitForever'),
            event(1.004, 'sched_switch: prev_pid=11 next_pid=0', process=0),
            event(1.011, 'sched_switch: prev_pid=0 next_pid=11', process=0),
            event(1.011, 'tracing_mark_write: E|7'),
            event(1.012, 'tracing_mark_write: E|7'),
            event(1.013, 'tracing_mark_write: E|7'),
            event(1.014, 'tracing_mark_write: E|7'),
            event(1.015, 'sched_switch: prev_pid=11 next_pid=0', process=0),
            event(2, 'tracing_mark_write: B|8|GPURasterizer::Draw', process=8),
            event(3, 'tracing_mark_write: E|8', process=8),
            event(4, 'tracing_mark_write: B|7|waitForever', thread=12),
            event(5, 'tracing_mark_write: E|7', thread=12),
        ], 7)
        self.assertEqual(report['stage_statistics']['GPURasterizer::Draw']['samples'], 1)
        self.assertEqual(report['stage_statistics']['waitForever']['samples'], 1)
        frame = report['slowest_raster_frames'][0]
        self.assertEqual(frame['raster_wall_ms'], 14)
        self.assertEqual(frame['raster_cpu_running_ms'], 6)
        self.assertEqual(frame['longest_stage_ms']['waitForever'], 7)
        self.assertEqual(frame['longest_stage_ms']['queueBuffer'], 9)

    def test_missing_scheduling_data_is_unavailable_instead_of_zero_cpu(self):
        report = module.analyze([
            event(1, 'tracing_mark_write: B|7|GPURasterizer::Draw'),
            event(1.01, 'tracing_mark_write: E|7'),
        ], 7)
        self.assertFalse(report['cpu_scheduling_observed'])
        self.assertIsNone(report['slowest_raster_frames'][0]['raster_cpu_running_ms'])

    def test_truncated_and_unrelated_events_do_not_create_completed_frames(self):
        report = module.analyze([
            'invalid log', event(1, 'tracing_mark_write: E|7'),
            event(2, 'tracing_mark_write: B|7|GPURasterizer::Draw'),
        ], 7)
        self.assertEqual(report['stage_statistics'], {})
        self.assertEqual(report['slowest_raster_frames'], [])


if __name__ == '__main__':
    unittest.main()
