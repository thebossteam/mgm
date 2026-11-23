s = open('index.html', encoding='utf-8').read()
import re
# find DOMContentLoaded
i = s.find("DOMContentLoaded")
print(s[i-100:i+200])
