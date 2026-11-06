"""Editable keybindings layered over the user's Hyprland Lua configuration.

Only changed bindings are overridden. Original configuration and arbitrary Lua
callbacks are never parsed for execution or rewritten. Known dispatchers and
literal launch commands can be imported; other bindings remain external.
"""
import ast
import ctypes
from functools import lru_cache
from copy import deepcopy
from datetime import datetime
import hashlib
import json
import os
import re
import subprocess

from ..theming.appearance import atomic_text
from ..core.state import ConfigError, atomic_json, read_object, state_lock

BEGIN = '-- BEGIN POLY SHELL SHORTCUTS'
END = '-- END POLY SHELL SHORTCUTS'
HOOK = BEGIN + '''
do
    local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    local file = config .. "/hypr/poly-shell-shortcuts.lua"
    local handle = io.open(file, "r")
    if handle then handle:close(); dofile(file) end
end
''' + END + '\n'
ACTIONS = [
    ('command', 'Launch program'), ('global', 'Shell action'),
    ('close-window', 'Close window'), ('fullscreen-window', 'Toggle fullscreen'),
    ('float-window', 'Float window'), ('toggle-split', 'Toggle split'),
    ('cycle-window', 'Switch active window'),
    ('focus-left', 'Focus left'), ('focus-right', 'Focus right'),
    ('focus-up', 'Focus up'), ('focus-down', 'Focus down'),
    ('workspace', 'Open workspace'), ('move-workspace', 'Move window to workspace'),
]
GLOBAL_ACTIONS = [('poly-shell:launcher', 'Applications'), ('poly-shell:quick-settings', 'Quick settings'),
                  ('poly-shell:notifications', 'Notifications'), ('poly-shell:overview', 'Overview'),
                  ('poly-shell:clipboard', 'Clipboard'), ('poly-shell:toggle-mode', 'Toggle Work / Vibe Mode'),
                  ('poly-shell:screenshot', 'Interactive Screenshot'),
                  ('poly-shell:power-menu', 'Power Menu'), ('poly-shell:task-manager', 'Task Manager')]
MODS = {'SUPER':64, 'CTRL':4, 'ALT':8, 'SHIFT':1}


@lru_cache(maxsize=1)
def keysyms():
    try:
        lib = ctypes.CDLL('libxkbcommon.so.0')
        lib.xkb_keysym_from_name.argtypes = [ctypes.c_char_p, ctypes.c_int]
        lib.xkb_keysym_from_name.restype = ctypes.c_uint
        return lib
    except OSError as exc:
        if os.name == 'nt':
            class _DummyXkb:
                _VALID_KEYSYMS = {
                    *(chr(c) for c in range(ord('a'), ord('z') + 1)),
                    *(chr(c) for c in range(ord('A'), ord('Z') + 1)),
                    *(chr(c) for c in range(ord('0'), ord('9') + 1)),
                    *(f"F{i}" for i in range(1, 36)),
                    "Return", "Space", "Tab", "Escape", "BackSpace", "Delete",
                    "Home", "End", "Page_Up", "Page_Down", "Print", "Insert",
                    "Up", "Down", "Left", "Right", "space", "escape", "return",
                    "equal", "minus", "plus", "bracketleft", "bracketright",
                    "semicolon", "apostrophe", "grave", "backslash", "comma",
                    "period", "slash",
                }
                def xkb_keysym_from_name(self, name, flags):
                    decoded = name.decode("utf-8", errors="ignore")
                    return 1 if (decoded.startswith("XF86") or decoded in self._VALID_KEYSYMS) else 0
            return _DummyXkb()
        raise ConfigError('Нужна библиотека libxkbcommon для проверки клавиш') from exc


def key(value):
    if not isinstance(value, str): raise ConfigError('Key combination must be a string')
    parts = [p.strip() for p in value.split('+')]
    if not parts or any(not p for p in parts): raise ConfigError('Specify key and modifiers, e.g. SUPER + E')
    modifiers = [p.upper().replace('CONTROL', 'CTRL').replace('WIN', 'SUPER') for p in parts[:-1]]
    if any(m not in MODS for m in modifiers) or len(set(modifiers)) != len(modifiers):
        raise ConfigError('Modifiers: SUPER, CTRL, ALT, SHIFT; without duplicates')
    button = parts[-1]
    if not re.fullmatch(r'(?:[A-Za-z0-9_]{1,48}|code:[0-9]{1,3})', button):
        raise ConfigError('Клавиша: латинская буква, цифра, F1…F35, Return, Print или code:номер')
    if not button.startswith('code:') and not keysyms().xkb_keysym_from_name(button.encode(),1): raise ConfigError('Неизвестная клавиша: '+button)
    if button.upper() in MODS: raise ConfigError('После модификатора нужна клавиша')
    if button.startswith('code:') and not 8 <= int(button[5:]) <= 767: raise ConfigError('Некорректный код клавиши')
    return ' + '.join([m for m in MODS if m in modifiers] + [button.upper() if len(button)==1 else button])


def signature(value):
    parts = key(value).split(' + ')
    return sum(MODS[m] for m in parts[:-1]), parts[-1].lower()


def split_args(value, separator=','):
    result, start, depth, quote, escaped = [], 0, 0, '', False
    i = 0
    while i < len(value):
        ch = value[i]
        if quote:
            if escaped: escaped = False
            elif ch == '\\': escaped = True
            elif ch == quote: quote = ''
        elif ch in ('"', "'"): quote = ch
        elif ch in '({[': depth += 1
        elif ch in ')}]': depth -= 1
        elif depth == 0 and value.startswith(separator, i):
            result.append(value[start:i].strip()); i += len(separator); start = i; continue
        i += 1
    result.append(value[start:].strip())
    return result


def literal(value, names):
    result = ''
    for token in split_args(value, '..'):
        if token in names: result += names[token]
        else:
            item = ast.literal_eval(token)
            if not isinstance(item, str): raise ValueError('not literal text')
            result += item
    return result


def row(shortcut, title, action, argument='', locked=False, repeat=False):
    shortcut = key(shortcut)
    return dict(id='source-'+hashlib.sha256(str(signature(shortcut)).encode()).hexdigest()[:20],
                source=shortcut, key=shortcut, title=title, action=action, argument=argument,
                enabled=True, locked=locked, repeat=repeat)


def source_rows(paths):
    path = paths.config.parent / 'hypr/hyprland.lua'
    if not path.is_file(): raise ConfigError('Редактор поддерживает Hyprland с hyprland.lua; файл не найден')
    text = path.read_text(encoding='utf-8')
    names = {'root':str(path.parent)+'/', 'indicator':''}
    found = re.search(r'^local indicator\s*=\s*([^\r\n]+)', text, re.M)
    if found:
        try: names['indicator'] = literal(found[1], names)
        except (ValueError, SyntaxError): pass
    rows = []
    for line in text.splitlines():
        match = re.fullmatch(r'\s*(run|hl\.bind)\((.*)\)\s*', line)
        if not match: continue
        args = split_args(match[2])
        if len(args) < 2: continue
        try:
            shortcut = literal(args[0], names)
            action, argument = '', ''
            if match[1] == 'run':
                action, argument = 'command', literal(args[1], names)
            else:
                expr = args[1]
                global_call = re.fullmatch(r'hl\.dsp\.global\((.*)\)', expr)
                if expr.startswith('hl.dsp.exec_cmd(') and expr.endswith(')'): action, argument = 'command', literal(expr[16:-1],names)
                elif global_call: action, argument = 'global', literal(global_call[1], names)
                elif expr == 'hl.dsp.window.close()': action = 'close-window'
                elif re.fullmatch(r'hl\.dsp\.window\.fullscreen\(\{\s*action\s*=\s*[\'"]toggle[\'"]\s*\}\)', expr) or expr == 'hl.dsp.window.fullscreen()': action = 'fullscreen-window'
                elif re.fullmatch(r'hl\.dsp\.window\.float\(\{\s*action\s*=\s*[\'"]toggle[\'"]\s*\}\)', expr): action = 'float-window'
                elif expr in ('hl.dsp.layout("togglesplit")', "hl.dsp.layout('togglesplit')"): action = 'toggle-split'
                elif expr == 'hl.dsp.window.focus_next()': action = 'cycle-window'
            if not action: continue
            title = dict(GLOBAL_ACTIONS).get(argument, dict(ACTIONS)[action] if action != 'command' else argument[:160])
            flags = args[2] if len(args)>2 else ''
            rows.append(row(shortcut, title, action, argument, bool(re.search(r'locked\s*=\s*true',flags)) or flags=='media',
                            bool(re.search(r'repeating\s*=\s*true',flags)) or flags=='media'))
        except (ValueError, SyntaxError): continue
    # Recognize only this project's exact loop templates; other user loops stay external.
    if '"SUPER + " .. direction, hl.dsp.focus({ direction = direction })' in text or '"SUPER + "..direction, hl.dsp.focus({direction=direction})' in text:
        for direction in ('left', 'right', 'up', 'down'):
            rows.append(row('SUPER + '+direction, dict(ACTIONS)['focus-'+direction], 'focus-'+direction))
    if ('local key = tostring(workspace % 10)' in text and
            '"SUPER + " .. key, hl.dsp.focus({ workspace = workspace })' in text):
        for workspace in range(1,11):
            rows.append(row('SUPER + '+str(workspace%10), 'Workspace '+str(workspace), 'workspace', str(workspace)))
            if '"SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace })' in text:
                rows.append(row('SUPER + SHIFT + '+str(workspace%10), 'Window to workspace '+str(workspace), 'move-workspace', str(workspace)))
    # Ambiguous or unsupported source keys stay external. Never reinterpret an
    # arbitrary callback or an application's unrelated global shortcut.
    imported=[]
    for item in rows:
        if sum(signature(item['key'])==signature(other['key']) for other in rows)!=1: continue
        try: validate([item],[item])
        except ConfigError: continue
        imported.append(item)
    return imported


def stored(paths):
    path = paths.config / 'shortcuts.json'
    if not path.exists(): return []
    data = read_object(path)
    if data.get('version')!=1 or not isinstance(data.get('overrides'), list) or len(data['overrides'])>250: raise ConfigError('Corrupted shortcuts file; original preserved / Повреждён файл')
    if any(not isinstance(r,dict) or not isinstance(r.get('id'),str) for r in data['overrides']): raise ConfigError('Corrupted shortcut records / Повреждены записи')
    if len({r['id'] for r in data['overrides']})!=len(data['overrides']): raise ConfigError('Duplicate shortcut entries / Повторяющиеся записи')
    return data['overrides']


def effective(paths):
    base = source_rows(paths)
    changes = {r['id']:r for r in stored(paths)}
    result = [deepcopy(changes.pop(r['id'],r)) for r in base]
    result.extend(deepcopy(list(changes.values())))
    return validate(result,base)


def hypr(*args):
    from ..adapters.base import SafeRunner
    result = SafeRunner.run(['hyprctl', *args], timeout=8.0)
    if result.returncode: raise ConfigError((result.stderr or result.stdout).strip() or 'Hyprland error / Ошибка Hyprland')
    return result.stdout


def active_binds():
    try: data = json.loads(hypr('-j','binds'))
    except ValueError as exc: raise ConfigError('Invalid Hyprland shortcuts response / Некорректный ответ Hyprland') from exc
    if not isinstance(data,list): raise ConfigError('Invalid Hyprland shortcuts list / Некорректный список сочетаний')
    return data


def bind_signature(bind):
    return bind.get('modmask',0), ('code:'+str(bind['keycode']) if bind.get('keycode') else bind.get('key','').lower())


def get(paths):
    values = effective(paths)
    managed = {signature(r['source']) for r in values if r['source']} | {signature(r['key']) for r in values}
    external = [dict(key=b.get('key') or 'code:'+str(b.get('keycode')),modmask=b.get('modmask'),submap=b.get('submap',''))
                for b in active_binds() if bind_signature(b) not in managed or b.get('submap')]
    return dict(values=values,actions=[dict(id=a,title=t) for a,t in ACTIONS],
                globals=[dict(id=a,title=t) for a,t in GLOBAL_ACTIONS],external=external)


def validate(values, base):
    if not isinstance(values,list) or len(values)>250: raise ConfigError('Maximum 250 shortcuts allowed / Допустимо не более 250')
    original = {r['id']:r for r in base}
    result, ids, keys = [],set(),set()
    fields = {'id','source','key','title','action','argument','enabled','locked','repeat'}
    for item in values:
        if not isinstance(item,dict) or set(item)!=fields: raise ConfigError('Invalid shortcut entry / Некорректная запись')
        value = dict(item)
        if not isinstance(value['id'],str) or not re.fullmatch(r'(?:source-[0-9a-f]{20}|custom-[a-zA-Z0-9-]{1,64})',value['id']) or value['id'] in ids:
            raise ConfigError('Invalid or duplicate identifier / Некорректный или повторяющийся')
        ids.add(value['id'])
        if value['id'] in original:
            if value['source']!=original[value['id']]['source']: raise ConfigError('Original shortcut modified; refresh list / Исходное сочетание изменено')
        elif value['source'] or not value['id'].startswith('custom-'): raise ConfigError('Original shortcut not found; refresh list / Исходное сочетание больше не найдено')
        value['key'] = key(value['key'])
        if any(type(value[k]) is not bool for k in ('enabled','locked','repeat')): raise ConfigError('Invalid shortcut flags / Некорректные флаги')
        if not isinstance(value['title'],str) or not 1<=len(value['title'].strip())<=160 or any(ord(c)<32 for c in value['title']): raise ConfigError('Title: 1 to 160 characters / Название: от 1 до 160')
        if value['action'] not in dict(ACTIONS): raise ConfigError('Unknown action')
        arg = value['argument']
        if not isinstance(arg,str) or len(arg)>4096 or any(ord(c)<32 for c in arg): raise ConfigError('Invalid action argument / Некорректный аргумент')
        if value['action']=='command' and not arg.strip(): raise ConfigError('Specify command to execute / Укажи команду')
        if value['action']=='global' and arg not in dict(GLOBAL_ACTIONS): raise ConfigError('Select shell action from list / Выбери действие')
        if value['action'] in ('workspace','move-workspace') and (not arg.isdigit() or not 1<=int(arg)<=99): raise ConfigError('Workspace number: 1..99 / Номер рабочего стола')
        if value['enabled']:
            sig = signature(value['key'])
            if sig in keys: raise ConfigError('Shortcut already in use / Сочетание уже используется: '+value['key'])
            keys.add(sig)
        result.append(value)
    if not set(original)<=ids: raise ConfigError('Original shortcuts must be disabled, not removed / Исходные сочетания нужно отключать')
    return result


def quote(value):
    # Lua 5.4 accepts UTF-8 strings. Escape controls explicitly; never emit JSON \u escapes.
    return '"'+value.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n').replace('\r','\\r')+'"'


def expression(item):
    action, arg = item['action'],item['argument']
    if action=='command': return 'hl.dsp.exec_cmd('+quote(arg)+')'
    if action=='global': return 'hl.dsp.global('+quote(arg)+')'
    if action=='close-window': return 'hl.dsp.window.close()'
    if action=='fullscreen-window': return 'hl.dsp.window.fullscreen({action="toggle"})'
    if action=='float-window': return 'hl.dsp.window.float({action="toggle"})'
    if action=='toggle-split': return 'hl.dsp.layout("togglesplit")'
    if action=='cycle-window': return 'hl.dsp.window.focus_next()'
    if action.startswith('focus-'): return 'hl.dsp.focus({direction='+quote(action[6:])+'})'
    if action=='workspace': return 'hl.dsp.focus({workspace='+str(int(arg))+'})'
    return 'hl.dsp.window.move({workspace='+str(int(arg))+'})'


def generate(changes):
    lines = ['-- Generated by Poly Shell. Edit in Settings > Hotkeys.']
    # Unbind all affected original keys before adding any, so swaps work.
    lines += ['hl.unbind('+quote(r['source'])+')' for r in changes if r['source']]
    for r in changes:
        if not r['enabled']: continue
        flags = '{description='+quote('Poly: '+r['title'])+',locked='+str(r['locked']).lower()+',repeating='+str(r['repeat']).lower()+'}'
        lines.append('hl.bind('+quote(r['key'])+','+expression(r)+','+flags+')')
    return '\n'.join(lines)+'\n'


def apply(paths, values, expected):
    with state_lock(paths):
        current = effective(paths)
        if expected!=current: raise ConfigError('Shortcuts changed in another window / в другом окне. Refresh.')
        base = source_rows(paths)
        values = validate(values,base)
        baseline = {r['id']:r for r in base}
        changes = [r for r in values if r!=baseline.get(r['id'])]
        # Protect external root/submap bindings, including unsupported callbacks and mouse gestures.
        owned = {signature(r['source']) for r in base} | {signature(r['key']) for r in current if r['enabled']}
        bindings = active_binds()
        external = [b for b in bindings if bind_signature(b) not in owned or b.get('submap') or b.get('release') or b.get('mouse')
                    or sum(bind_signature(o)==bind_signature(b) for o in bindings)>1]
        for r in changes:
            if any((r['enabled'] and bind_signature(b)==signature(r['key'])) or (r['source'] and bind_signature(b)==signature(r['source'])) for b in external):
                raise ConfigError('Conflict with external Hyprland shortcut / Конфликт: '+r['key'])
        config = paths.config.parent / 'hypr/hyprland.lua'
        generated = config.with_name('poly-shell-shortcuts.lua')
        saved = paths.config / 'shortcuts.json'
        text = config.read_text(encoding='utf-8')
        if generated.exists() and generated.read_text(encoding='utf-8')!=generate(stored(paths)):
            raise ConfigError('Generated shortcuts file modified manually / вручную; file preserved')
        if BEGIN in text or END in text:
            if text.count(HOOK)!=1: raise ConfigError('Shortcuts hook modified manually / вручную; file preserved')
            text = text.replace(HOOK,'').rstrip()+'\n\n'+HOOK
        else: text = text.rstrip()+'\n\n'+HOOK
        before = {p:p.read_bytes() if p.exists() else None for p in (config,generated,saved)}
        errors_before = [e for e in json.loads(hypr('-j','configerrors')) if isinstance(e,str) and e.strip()]
        backup = paths.state/'backups'/('shortcuts-'+datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
        for path,data in before.items():
            if data is not None:
                backup.mkdir(mode=0o700,parents=True,exist_ok=True)
                (backup/path.name).write_bytes(data)
        try:
            atomic_text(generated,generate(changes));atomic_text(config,text)
            atomic_json(saved,dict(version=1,overrides=changes))
            hypr('reload','config-only')
            errors_after = [e for e in json.loads(hypr('-j','configerrors')) if isinstance(e,str) and e.strip()]
            if any(error not in errors_before for error in errors_after): raise ConfigError('Hyprland rejected shortcuts: '+str(errors_after))
            binds = active_binds()
            for r in changes:
                if r['enabled'] and not any(bind_signature(b)==signature(r['key']) and b.get('description')=='Poly: '+r['title'] for b in binds):
                    raise ConfigError('Hyprland did not register shortcut / не зарегистрировал: '+r['key'])
            wanted = {signature(r['key']) for r in values if r['enabled']}
            for r in changes:
                if r['source'] and signature(r['source']) not in wanted and any(bind_signature(b)==signature(r['source']) for b in binds):
                    raise ConfigError('Hyprland did not remove previous shortcut: '+r['source'])
        except Exception as exc:
            for path,data in before.items():
                if data is None: path.unlink(missing_ok=True)
                else: atomic_text(path,data.decode())
            try: hypr('reload','config-only')
            except ConfigError as rollback: raise ConfigError('Cannot restore Hyprland: '+str(rollback)) from exc
            raise ConfigError('Changes rolled back / отменены: '+str(exc)) from exc
        return dict(saved=True,values=values,backup=str(backup))


def shortcuts_control(paths,action,payload):
    if action=='get': return get(paths)
    if not isinstance(payload,dict): raise ConfigError('Invalid shortcuts request / Некорректный запрос')
    return apply(paths,payload.get('values'),payload.get('expected'))
