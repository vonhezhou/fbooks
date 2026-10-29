#!/usr/bin/env python3
"""从本机 atrace 提取目标 App 的栅格等待摘要，不输出原始进程或内容信息。"""
import argparse
from bisect import bisect_left
from collections import defaultdict
import json
from pathlib import Path
import re

EVENT = re.compile(r'-(\d+)\s+\(\s*([^)]*)\)\s+\[(\d+)\].*?\s(\d+\.\d+):\s+(.*)')
STAGES = {
    'GPURasterizer::Draw', 'AcquireNextImageKHR',
    'CompositorContext::ScopedFrame::Raster', 'SurfaceFrame::Submit',
    'QueuePresentKHR', 'queueBuffer', 'waitForever',
}


def analyze(lines, process_id):
    process_id = str(process_id)
    stacks = defaultdict(list)
    known_threads = set()
    running = {}
    intervals = defaultdict(list)
    spans = []
    for line in lines:
        match = EVENT.search(line)
        if not match:
            continue
        thread, process, cpu, stamp, event = match.groups()
        timestamp = float(stamp)
        if event.startswith('sched_switch:'):
            next_thread = re.search(r'next_pid=(\d+)', event)
            if next_thread:
                previous = running.get(cpu)
                if previous and previous[0] in known_threads:
                    intervals[previous[0]].append((previous[1], timestamp))
                running[cpu] = (next_thread[1], timestamp)
        if process.strip() != process_id:
            continue
        known_threads.add(thread)
        prefix = 'tracing_mark_write: B|' + process_id + '|'
        if event.startswith(prefix):
            stacks[thread].append((event[len(prefix):], timestamp))
        elif event.startswith('tracing_mark_write: E') and stacks[thread]:
            name, start = stacks[thread].pop()
            if name in STAGES:
                spans.append((thread, name, start, timestamp))

    by_thread = {}
    for thread, values in intervals.items():
        values.sort()
        starts = [value[0] for value in values]
        ends = [value[1] for value in values]
        prefix = [0.0]
        for start, end in values:
            prefix.append(prefix[-1] + end - start)
        by_thread[thread] = (starts, ends, prefix)

    def cpu_ms(thread, start, end):
        values = by_thread.get(thread)
        if not values:
            return 0.0
        starts, ends, prefix = values
        left = bisect_left(ends, start)
        right = bisect_left(starts, end)
        if right <= left:
            return 0.0
        total = prefix[right] - prefix[left]
        total -= max(0, start - starts[left])
        total -= max(0, ends[right - 1] - end)
        return max(0.0, total * 1000)

    # 等待标签也出现在 I/O、主线程等位置；统计只保留出现过栅格帧的线程。
    raster_threads = {thread for thread, name, _, _ in spans if name == 'GPURasterizer::Draw'}
    spans = [span for span in spans if span[0] in raster_threads]
    groups = defaultdict(list)
    for _, name, start, end in spans:
        groups[name].append((end - start) * 1000)
    statistics = {}
    for name, values in sorted(groups.items()):
        values.sort()
        statistics[name] = {
            'samples': len(values),
            'mean_ms': round(sum(values) / len(values), 3),
            'p95_ms': round(values[int((len(values) - 1) * .95)], 3),
            'max_ms': round(values[-1], 3),
        }
    draws = sorted((s for s in spans if s[1] == 'GPURasterizer::Draw'),
                   key=lambda s: s[3] - s[2], reverse=True)[:12]
    slow = []
    for thread, _, start, end in draws:
        # 同层嵌套 queueBuffer / waitForever 不能相加，分别保留最长等待。
        children = [(name, (b - a) * 1000) for tid, name, a, b in spans
                    if tid == thread and a >= start and b <= end]
        slow.append({
            'raster_wall_ms': round((end - start) * 1000, 3),
            'raster_cpu_running_ms': round(cpu_ms(thread, start, end), 3) if thread in by_thread else None,
            'longest_stage_ms': {
                name: round(max((duration for kind, duration in children if kind == name), default=0), 3)
                for name in sorted(STAGES - {'GPURasterizer::Draw'})
            },
        })
    return {
        'cpu_scheduling_observed': bool(by_thread),
        'stage_statistics': statistics,
        'slowest_raster_frames': slow,
        'limitations': [
            'CPU time comes from observed sched_switch intervals; boundary intervals may be incomplete.',
            'Raster wall time includes blocking and scheduling; CPU running time is not GPU execution time.',
            'Nested stage durations overlap and must not be added.',
            'Tracing perturbs timings; this report diagnoses waits and does not establish a speedup.',
            'No frame presentation or dropped-frame rate is inferred.',
        ],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--trace', required=True)
    parser.add_argument('--pid', required=True, type=int)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    with Path(args.trace).open(errors='replace') as stream:
        report = analyze(stream, args.pid)
    if not report['stage_statistics'].get('GPURasterizer::Draw'):
        parser.error('No complete target-app raster spans; capture during animation with trace-systrace enabled')
    Path(args.output).write_text(json.dumps(report, indent=2) + '\n')
    print('Raster trace summary saved')


if __name__ == '__main__':
    main()
