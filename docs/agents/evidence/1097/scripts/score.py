import sys, difflib, ast
# score.py <expected> <repr of field value>: letters of expected typed in order (LCS), out of len.
exp = sys.argv[1]
got = ast.literal_eval(sys.argv[2]) or ''
if got == 'Recherche': got = ''
m = difflib.SequenceMatcher(None, exp, got.lower(), autojunk=False)
print(f"{sum(b.size for b in m.get_matching_blocks())}/{len(exp)}")
