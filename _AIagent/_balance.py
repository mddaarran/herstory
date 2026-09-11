import re
c = open(r"C:\Users\maodr\Desktop\Herstory\_AIagent\02_Godot_Project\herstory\scripts\Main.gd", encoding="utf-8").read()
# strip comments
code = re.sub(r"#.*$", "", code, flags=re.M)
# strip strings
code = re.sub(r'"[^"]*"', '', code)
code = re.sub(r"'[^']*'", '', code)
# strip triple-quoted
code = re.sub(r'"""[\s\S]*?"""', '', code)
o = cl = 0
for i, ch in enumerate(code):
    if ch in "([{": o += 1
    elif ch in ")]}": cl += 1
print("balance:", o - cl, "open:", o, "close:", cl)
# show lines around problematic area
import sys
line = 1
running_o = 0
running_c = 0
for i, ch in enumerate(c):
    if ch == "\n":
        line += 1
    elif ch in "([{": running_o += 1
    elif ch in ")]}": running_c += 1
    if abs(running_o - running_c) > 0 and ch == "\n":
        # print every line with diff
        pass