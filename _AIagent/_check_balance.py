import re
src = open(r"C:\Users\maodr\Desktop\Herstory\_AIagent\02_Godot_Project\herstory\scripts\Main.gd", encoding="utf-8").read()

# Tokenize: walk through source, track strings and comments
i = 0
n = len(src)
out = []
balance = {')':'(', ']':'[', '}':'{'}
opens = set('([{')
closes = set(')]}')
stack = []
line = 1
last_err_line = 0
in_string = None
while i < n:
    ch = src[i]
    if ch == '\n':
        line += 1
    # Handle comments: # to EOL (outside string)
    if in_string is None and ch == '#':
        while i < n and src[i] != '\n':
            i += 1
        continue
    # Handle strings
    if in_string is not None:
        if ch == '\\' and i+1 < n:
            i += 2
            continue
        if ch == in_string:
            in_string = None
        i += 1
        continue
    else:
        if ch in ('"', "'"):
            in_string = ch
            i += 1
            continue
    # Now handle parens/brackets
    if ch in opens:
        stack.append((ch, line))
    elif ch in closes:
        if not stack:
            print("UNMATCHED CLOSE at line", line, ch)
            break
        op, op_line = stack.pop()
        if balance[ch] != op:
            print("MISMATCH at line", line, "got", ch, "expected close of", op, "from line", op_line)
            break
    i += 1
print("Stack remaining:", len(stack))
if stack:
    for op, op_line in stack:
        print("Unclosed", op, "at line", op_line)