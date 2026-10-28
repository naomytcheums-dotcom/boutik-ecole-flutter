import os,re
names=sorted(f[:-4] for f in os.listdir('assets/icons') if f.endswith('.svg'))
def camel(n):
    p=re.split(r'[-]',n); s=p[0]+''.join(x.capitalize() for x in p[1:])
    return {'switch':'switchIcon'}.get(s,s)
lines=["// Généré par tool/gen_icons.py depuis assets/icons (Lucide, licence ISC).","// ignore_for_file: constant_identifier_names","","abstract final class AppIcons {"]
for n in names: lines.append(f"  static const {camel(n)} = 'assets/icons/{n}.svg';")
lines.append("}")
open('lib/core/theme/app_icons.dart','w',encoding='utf-8').write('\n'.join(lines)+'\n')
print(len(names))
