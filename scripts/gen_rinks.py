#!/usr/bin/env python3
"""rinks_kr.json → HockeyCore/Sources/HockeyCore/RinkDirectoryData.swift
사용: python3 scripts/gen_rinks.py data/rinks_kr.json"""
import json, sys, pathlib
src = pathlib.Path(sys.argv[1]); data = json.loads(src.read_text())
rinks = [r for r in data["rinks"] if r.get("status") in ("open", "unsure") and r.get("address")]
def s(x): return '"' + x.replace("\\", "\\\\").replace('"', '\\"') + '"'
def f(x): return "nil" if x is None else repr(float(x))
lines = ["import Foundation", "", "// 자동 생성 파일(scripts/gen_rinks.py). 손으로 고치지 말고 rinks_kr.json을 고친 뒤 다시 만든다.",
         "extension RinkDirectory {", "    public static let all: [RinkEntry] = ["]
seen=set()
for r in sorted(rinks, key=lambda r: r["address"]):
    if r["name"] in seen: continue
    seen.add(r["name"])
    al = ", ".join(s(a) for a in dict.fromkeys(r.get("aliases") or []))
    lines.append(f"        RinkEntry(name: {s(r['name'])}, aliases: [{al}], address: {s(r['address'])}, latitude: {f(r.get('lat'))}, longitude: {f(r.get('lon'))}, verified: {'true' if r['status']=='open' else 'false'}),")
lines += ["    ]", "}", ""]
out = pathlib.Path(__file__).resolve().parents[1] / "HockeyCore/Sources/HockeyCore/RinkDirectoryData.swift"
out.write_text("\n".join(lines)); print(f"{len(seen)} rinks → {out}")
