import sys, json
for l in sys.stdin:
    try: d = json.loads(l)
    except Exception: continue
    print(d.get('phase', d['type']), d.get('t'), 'heap', d.get('heapBytes', 0) >> 20, 'wc', d.get('webContentFootprintMB'), 'peak', d.get('webContentPhasePeakMB'), d.get('decodeMs', ''), (d.get('message') or d.get('text') or '')[:120])
