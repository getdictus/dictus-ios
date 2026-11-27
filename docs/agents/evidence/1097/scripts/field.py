import json,sys
# Prints the value of the first text field in an axe describe-ui dump.
def walk(n):
    if isinstance(n,list):
        for x in n:
            r=walk(x)
            if r is not None: return r
        return None
    if n.get('type') in ('TextField','SearchField'):
        return n.get('AXValue') or n.get('value') or ''
    return walk(n.get('children',[]))
print(repr(walk(json.load(sys.stdin))))
