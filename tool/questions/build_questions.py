#!/usr/bin/env python3
"""Builds lib/data/questions.json from the hand-written sources in src/ and
the verified fact tables in tables.py.

Usage:  python3 tool/questions/build_questions.py

The output is deterministic (seeded), so re-running it produces the same file.
Each question has exactly four unique options and one correct answer; the
script fails loudly on duplicates or malformed rows.
"""

import hashlib
import json
import random
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import tables as T  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).parent / 'src'
OUT = ROOT / 'lib' / 'data' / 'questions.json'

CATEGORIES = {
    'islamic': 'ثقافة إسلامية',
    'history': 'تاريخ',
    'geography': 'جغرافيا',
    'science': 'علوم',
    'language': 'لغة وأدب',
    'arts': 'فنون وأدب عالمي',
    'sports': 'رياضة',
    'tech': 'تقنية',
    'general': 'ثقافة عامة',
    'math': 'رياضيات',
}

ORDINALS = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس',
            'السابع', 'الثامن', 'التاسع', 'العاشر', 'الحادي عشر', 'الثاني عشر']

questions = []


def add(cat, d, q, correct, wrongs, src):
    questions.append({'c': cat, 'd': int(d), 'q': q.strip(),
                      'right': str(correct).strip(),
                      'wrong': [str(w).strip() for w in wrongs], 'src': src})


def rng_for(key):
    return random.Random(int(hashlib.sha1(key.encode()).hexdigest()[:12], 16))


def pick(pool, answer, n, key, exclude=()):
    """n distinct distractors from pool, never equal to / excluded by answer."""
    first = answer.split()[0]
    cands = sorted({p for p in pool
                    if p != answer and p not in exclude and p.split()[0] != first})
    r = rng_for(key)
    r.shuffle(cands)
    if len(cands) < n:
        raise ValueError(f'not enough distractors for {key}')
    return cands[:n]


def near_numbers(value, key, spread=None, n=3, positive=True):
    r = rng_for(key)
    spread = spread or max(3, abs(value) // 5)
    out = set()
    while len(out) < n:
        v = value + r.choice([-1, 1]) * r.randint(1, spread)
        if v != value and (v > 0 or not positive):
            out.add(v)
    return sorted(out)


# ---------------------------------------------------------------- hand-written
for path in sorted(SRC.glob('*.txt')):
    cat = path.stem
    assert cat in CATEGORIES, cat
    for ln, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split('|')
        if len(parts) != 6:
            sys.exit(f'{path.name}:{ln}: expected 6 fields, got {len(parts)}')
        add(cat, parts[0], parts[1], parts[2], parts[3:], f'{path.name}:{ln}')

# ------------------------------------------------------------------- generated
regions = {}
for country, cap, region, d in T.CAPITALS:
    regions.setdefault(region, []).append(cap)
all_caps = [c for _, c, _, _ in T.CAPITALS]
for country, cap, region, d in T.CAPITALS:
    pool = regions[region] if len(regions[region]) >= 6 else all_caps
    add('geography', d, f'ما عاصمة {country}؟', cap,
        pick(pool, cap, 3, 'cap' + country), 'tables:capitals')

for country, cur, d in T.CURRENCIES:
    add('geography', d, f'ما اسم عملة {country}؟', cur,
        pick(T.CURRENCY_POOL, cur, 3, 'cur' + country), 'tables:currencies')

el_names = [n for _, n, _ in T.ELEMENTS]
for sym, name, d in T.ELEMENTS:
    add('science', d, f'ما العنصر الكيميائي الذي رمزه ({sym})؟', name,
        pick(el_names, name, 3, 'el' + sym), 'tables:elements')

for name, z, d in T.ATOMIC_NUMBERS:
    add('science', d, f'ما العدد الذري لعنصر {name}؟', z,
        near_numbers(z, 'z' + name, spread=4 if z < 10 else 6), 'tables:atomic')

GERMANY = {'ألمانيا', 'ألمانيا الغربية'}
hosts = sorted({h for _, h, _ in T.WORLD_CUPS} | {'هولندا', 'البرتغال'})
winners = sorted({w for _, _, w in T.WORLD_CUPS} | {'هولندا', 'المجر', 'كرواتيا'})
for year, host, winner in T.WORLD_CUPS:
    d = 2 if year >= 1994 else 3
    if year not in T.WC_HOST_SKIP:
        add('sports', d, f'أي دولة استضافت كأس العالم لكرة القدم عام {year}؟', host,
            pick(hosts, host, 3, f'wch{year}', GERMANY if host in GERMANY else ()),
            'tables:worldcup')
    add('sports', d, f'أي منتخب فاز بكأس العالم لكرة القدم عام {year}؟', winner,
        pick(winners, winner, 3, f'wcw{year}', GERMANY if winner in GERMANY else ()),
        'tables:worldcup')

oly_cities = sorted({c for _, c in T.OLYMPICS} | {'مدريد', 'إسطنبول', 'القاهرة'})
for year, city in T.OLYMPICS:
    add('sports', 2 if year >= 1992 else 3,
        f'أي مدينة استضافت الألعاب الأولمبية الصيفية عام {year}؟', city,
        pick(oly_cities, city, 3, f'oly{year}'), 'tables:olympics')

for i, month in enumerate(T.HIJRI_MONTHS):
    d = 1 if month in ('محرم', 'رمضان', 'ذو الحجة') else (2 if i in (6, 7, 9, 10) else 3)
    right = f'الشهر {ORDINALS[i]}'
    wrongs = [f'الشهر {ORDINALS[j]}' for j in
              sorted({(i + k) % 12 for k in (-2, -1, 1, 2)}, key=lambda j: abs(j - i))[:3]]
    add('islamic', d, f'ما ترتيب شهر {month} في التقويم الهجري؟', right, wrongs,
        'tables:hijri')

# ------------------------------------------------------------------------ math
r = random.Random(2024)
pairs = [(a, b) for a in range(6, 16) for b in range(a, 16) if 10 not in (a, b)]
r.shuffle(pairs)
for a, b in pairs[:40]:
    v = a * b
    d = 1 if b <= 9 else 2
    wrong = {v + a, v - b, (a + 1) * (b - 1) if (a + 1) * (b - 1) != v else v + 10, v + 10}
    wrong.discard(v)
    wrong = sorted(wrong)[:3]
    add('math', d, f'ما ناتج {a} × {b}؟', v, wrong, 'math:mul')

for n in range(11, 26):
    add('math', 2, f'ما مربع العدد {n}؟', n * n,
        [n * n + n, n * n - n, (n + 1) * (n + 1)], 'math:square')
for n in range(12, 31):
    add('math', 2 if n <= 20 else 3, f'ما الجذر التربيعي للعدد {n * n}؟', n,
        near_numbers(n, f'sqrt{n}', spread=3), 'math:sqrt')
for n in range(2, 11):
    add('math', 2 if n <= 5 else 3, f'ما مكعب العدد {n}؟', n ** 3,
        [n * n, n ** 3 + n * n, n ** 3 - n],
        'math:cube')

pct_items = [(p, n) for p in (5, 10, 15, 20, 25, 30, 40, 50, 60, 75)
             for n in (40, 60, 80, 120, 200, 240, 300, 360, 400, 500)
             if p * n % 100 == 0]
r.shuffle(pct_items)
for p, n in pct_items[:30]:
    v = p * n // 100
    wrong = sorted({v + n // 10, max(1, v - n // 20), v * 2} - {v})
    if len(wrong) < 3:
        wrong.append(v + 5)
    add('math', 2 if p in (10, 25, 50) else 3, f'كم يساوي {p}% من {n}؟', v,
        wrong[:3], 'math:percent')

for name, sides in T.POLYGONS:
    add('math', 1 if sides <= 6 else 2, f'كم عدد أضلاع {name}؟', sides,
        near_numbers(sides, 'poly' + name, spread=2), 'math:polygon')
    if sides > 3:
        s = 180 * (sides - 2)
        wrong = [w for w in dict.fromkeys([s + 180, s - 180, sides * 90, s + 90, s + 360])
                 if w != s][:3]
        add('math', 3, f'ما مجموع قياسات الزوايا الداخلية في {name} المحدب؟', f'{s}°',
            [f'{w}°' for w in wrong], 'math:angles')


def roman(n):
    vals = [(1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), (100, 'C'), (90, 'XC'),
            (50, 'L'), (40, 'XL'), (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I')]
    out = ''
    for v, s in vals:
        while n >= v:
            out += s
            n -= v
    return out


for n in (4, 9, 14, 19, 40, 49, 90, 99, 400, 900, 1990, 2024):
    others = [n + 1, n - 1, n + 10] if n > 10 else [n + 1, n - 1, n + 5]
    add('math', 2 if n < 100 else 3, f'كيف يُكتب العدد {n} بالأرقام الرومانية؟',
        roman(n), [roman(o) for o in others], 'math:roman')
for n in (6, 11, 15, 29, 44, 50, 100, 500, 1000):
    add('math', 2 if n < 100 else 3, f'ما قيمة الرقم الروماني {roman(n)}؟', n,
        near_numbers(n, f'rv{n}', spread=max(2, n // 5)), 'math:roman')


def is_prime(k):
    return k > 1 and all(k % i for i in range(2, int(k ** 0.5) + 1))


primes = [p for p in range(23, 100) if is_prime(p)]
tricky = [k for k in range(21, 100) if not is_prime(k) and k % 2 and k % 5]
r.shuffle(primes)
for p in primes[:14]:
    rr = rng_for(f'prime{p}')
    add('math', 3, 'أي الأعداد التالية عدد أولي؟', p, rr.sample(tricky, 3),
        f'math:prime{p}')

for a, b, c in [(2, 3, 4), (5, 2, 6), (10, 4, 3), (7, 3, 5), (8, 2, 9),
                (6, 5, 4), (12, 3, 2), (9, 4, 7), (4, 6, 3), (3, 8, 2)]:
    v = a + b * c
    add('math', 2, f'ما ناتج {a} + {b} × {c}؟', v,
        sorted({(a + b) * c, v + 1, v - 2} - {v}), 'math:order')

for n, unit, factor, unit2, d in [
        (3, 'كيلومترات', 1000, 'متر', 1), (5, 'أمتار', 100, 'سنتيمتر', 1),
        (2, 'كيلوغرام', 1000, 'غرام', 1), (4, 'لترات', 1000, 'مليلتر', 2),
        (3, 'ساعات', 60, 'دقيقة', 1), (2, 'ساعتين', 3600, 'ثانية', 2),
        (7, 'أسابيع', 7, 'يوم', 2), (2, 'طن', 1000, 'كيلوغرام', 2),
        (1, 'يوم', 1440, 'دقيقة', 3), (6, 'سنتيمترات', 10, 'مليمتر', 2)]:
    v = n * factor
    if n == 2 and unit == 'ساعتين':
        q = f'كم {unit2} في ساعتين؟'
    else:
        q = f'كم {unit2} في {n} {unit}؟' if n != 1 else f'كم {unit2} في {unit} واحد؟'
    add('math', d, q, v, [v // 10, v * 10, v + factor // 2 or v + 1], 'math:units')

# ------------------------------------------------------------------ validation
AR_DIAC = re.compile(r'[ً-ْـ]')


def norm(s):
    s = AR_DIAC.sub('', s)
    s = re.sub('[إأآ]', 'ا', s).replace('ة', 'ه').replace('ى', 'ي')
    return re.sub(r'[\s؟?،,:"\'«»()]+', '', s)


errors = []
seen = {}
for i, q in enumerate(questions):
    opts = [q['right']] + q['wrong']
    if len(q['wrong']) != 3:
        errors.append(f"{q['src']}: needs 3 wrong options")
    if any(not o for o in opts):
        errors.append(f"{q['src']}: empty option")
    if len({norm(o) for o in opts}) != 4:
        errors.append(f"{q['src']}: duplicate options {opts}")
    if q['d'] not in (1, 2, 3):
        errors.append(f"{q['src']}: bad difficulty")
    # The prime questions share wording by design; key them by their options.
    key = norm(q['q']) + ('|' + norm(q['right']) if q['src'].startswith('math:prime') else '')
    if key in seen:
        errors.append(f"duplicate question: {q['src']} and {seen[key]}: {q['q']}")
    seen[key] = q['src']

if errors:
    sys.exit('\n'.join(errors))

out = []
for i, q in enumerate(questions, 1):
    opts = [q['right']] + q['wrong']
    rng_for('opts' + q['q'] + q['right']).shuffle(opts)
    out.append({'id': i, 'c': q['c'], 'd': q['d'], 'q': q['q'], 'o': opts,
                'a': opts.index(q['right'])})

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps({'version': 1, 'categories': CATEGORIES, 'questions': out},
                          ensure_ascii=False, separators=(',', ':')), encoding='utf-8')

by_d = {1: 0, 2: 0, 3: 0}
by_c = {}
for q in out:
    by_d[q['d']] += 1
    by_c[q['c']] = by_c.get(q['c'], 0) + 1
print(f'{len(out)} questions -> {OUT.relative_to(ROOT)}')
print('by difficulty:', by_d)
print('by category:', dict(sorted(by_c.items(), key=lambda kv: -kv[1])))
