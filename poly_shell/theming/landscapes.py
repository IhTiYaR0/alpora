"""Small native SVG theme landscapes; immutable URLs avoid Qt image-cache staleness."""
import hashlib
import json

KINDS = {'alpine': 'alpine', 'moon-lake': 'moon', 'forest-mist': 'forest',
         'warm-desert': 'desert', 'northern-lights': 'glacier', 'rose-sunset': 'coast'}
VERSION = 1


def blend(a, b, t):
    return '#' + ''.join(f'{round(int(a[i:i+2],16)*(1-t)+int(b[i:i+2],16)*t):02x}' for i in (1,3,5))


def kind_for(ident):
    if ident == 'timeline': return 'alpine'
    if ident in KINDS: return KINDS[ident]
    # User wallpapers get a stable variation without sampling while rendering.
    return tuple(KINDS.values())[int(hashlib.sha256(ident.encode()).hexdigest()[:4],16) % 6]


def palette_colors(p):
    return [blend(p['background'],p['cool'],.25), blend(p['surface'],p['cool'],.30),
            blend(p['surface'],p['accent'],.28), blend(p['surface'],p['accent'],.48),
            blend(p['accent'],p['text'],.15), blend(p['surface'],p['secondary'],.42),
            blend(p['background'],p['accent'],.16)]


def svg_for(kind, palette, compact=False):
    c = palette_colors(palette)
    parts = []
    def polygon(points, tone): parts.append(f'<polygon points="{points}" fill="{c[tone]}"/>')
    def path(d, tone): parts.append(f'<path d="{d}" fill="{c[tone]}"/>')
    # All profiles share a quiet 600x110 baseline and contain no text or external
    # references. Shape differences are deliberate, not random runtime noise.
    if kind == 'alpine':
        polygon('0,110 65,82 110,88 187,30 235,59 300,5 357,57 389,46 480,110',0)
        polygon('88,110 187,30 179,78 223,110',1)
        polygon('187,30 202,65 223,110 179,78',3)
        polygon('200,110 300,5 288,65 333,110',2)
        polygon('300,5 326,57 367,110 288,65',3)
        polygon('300,5 315,37 306,29 297,43 288,42',4)
        polygon('324,110 416,37 450,62 509,45 600,110',1)
        polygon('416,37 445,88 474,110 450,62',5)
        polygon('470,110 509,45 538,79 600,110',2)
        polygon('509,45 525,86 548,110 538,79',3)
    elif kind == 'moon':
        polygon('0,110 92,75 137,84 205,38 249,67 318,2 352,45 395,29 455,78 507,57 600,110',0)
        polygon('111,110 205,38 192,86 245,110',1)
        polygon('205,38 228,73 245,110 192,86',3)
        polygon('224,110 318,2 309,43 337,77 319,110',2)
        polygon('318,2 352,45 375,110 337,77 309,43',4)
        polygon('337,110 395,29 389,71 428,110',1)
        polygon('395,29 419,69 456,110 428,110 389,71',3)
        polygon('442,110 507,57 532,87 600,110',2)
        polygon('507,57 521,93 544,110 532,87',5)
    elif kind == 'forest':
        polygon('0,110 80,76 123,83 202,49 263,72 337,32 400,59 454,45 530,83 600,110',0)
        polygon('45,110 130,85 218,63 280,86 362,59 443,80 498,67 600,110',1)
        polygon('200,110 337,32 320,71 356,110',2)
        polygon('337,32 366,71 399,110 356,110 320,71',3)
        for x,y,w in [(55,68,26),(96,52,33),(141,77,23),(442,59,30),(488,35,38),(540,68,27)]:
            polygon(f'{x},{y} {x-w//2},{y+22} {x-w//3},{y+22} {x-w},{y+43} {x-w//2},{y+43} {x-w-4},110 {x+w+4},110 {x+w//2},{y+43} {x+w},{y+43} {x+w//3},{y+22} {x+w//2},{y+22}',6)
            polygon(f'{x},{y} {x},{110} {x+w+4},110 {x+w//2},{y+43} {x+w},{y+43} {x+w//3},{y+22} {x+w//2},{y+22}',2)
    elif kind == 'desert':
        polygon('10,110 135,87 198,77 219,30 278,30 293,51 309,51 330,91 425,88 455,56 498,56 515,97 600,110',0)
        polygon('198,77 219,30 231,42 225,79 253,110 162,110',2)
        polygon('219,30 278,30 293,51 260,54 253,110 225,79 231,42',3)
        polygon('260,54 293,51 309,51 330,91 367,110 253,110',1)
        path('M0 110Q110 35 247 78T480 91Q550 91 600 110Z',2)
        path('M0 110Q110 35 247 78Q146 71 106 110Z',5)
        path('M180 110Q337 43 453 81T600 110Z',3)
        path('M180 110Q337 43 453 81Q353 64 309 110Z',4)
        path('M393 110Q491 87 600 110Z',1)
    elif kind == 'glacier':
        polygon('0,110 79,69 105,87 162,28 198,65 251,11 294,62 332,30 365,63 407,5 455,55 479,37 529,82 600,110',0)
        for a,peak,b,y in [(95,162,227,28),(181,251,319,11),(273,332,390,30),(331,407,487,5),(435,479,558,37)]:
            polygon(f'{a},110 {peak},{y} {peak-9},{y+40} {peak+7},91 {peak-5},110',2)
            polygon(f'{peak},{y} {b},110 {peak-5},110 {peak+7},91 {peak-9},{y+40}',3)
            polygon(f'{peak},{y} {peak+20},{y+29} {peak+9},{y+25} {peak+5},{y+35} {peak-3},{y+24} {peak-13},{y+31}',4)
        polygon('20,110 119,89 197,110 270,94 358,110 466,83 600,110',1)
    else:  # Terraced coastal cliffs, with a low sea-side skyline on the right.
        polygon('0,110 68,79 93,47 167,47 186,61 232,58 271,76 300,76 356,110',0)
        polygon('78,110 93,47 167,47 163,71 180,75 174,110',2)
        polygon('93,47 167,47 163,58 120,60 112,110 78,110',5)
        polygon('167,47 186,61 232,58 223,80 241,91 237,110 174,110 180,75 163,71',3)
        polygon('232,58 271,76 300,76 294,89 311,110 237,110 241,91 223,80',1)
        polygon('344,110 393,82 430,82 448,97 482,97 508,110',2)
        polygon('393,82 407,95 401,110 374,110',4)
        path('M317 108Q396 103 480 108T600 108L600 110H317Z',5)
    # The clock decoration uses the same identity but a deliberate short crop:
    # the compact view fills its 96x36 slot without altering the clock layout.
    viewbox = '100 0 330 110' if compact else '0 0 600 110'
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{viewbox}">' + ''.join(parts) + '</svg>'


def landscape_assets(paths, ident, palette):
    kind = kind_for(ident)
    token = hashlib.sha256(json.dumps({'version':VERSION,'id':ident,'palette':palette},sort_keys=True).encode()).hexdigest()[:16]
    directory = paths.state / 'landscapes'
    ridge = directory / ('ridge-'+token+'.svg')
    clock = directory / ('clock-'+token+'.svg')
    return {'ridge':str(ridge), 'clockRidge':str(clock), 'landscapeKind':kind}, {
        ridge:svg_for(kind,palette), clock:svg_for(kind,palette,True)}
