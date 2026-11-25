"""TestFlight 피드백(스크린샷+글, 충돌)을 App Store Connect API로 읽어 out/ 에 저장한다. 읽기 전용.

필요 환경변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH(.p8 경로). 로그에는 개수만 찍고 내용·메일은 찍지 않는다.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

import jwt  # pyjwt[crypto]

BUNDLE_ID = "com.aspynlim.hockeydiary"
API = "https://api.appstoreconnect.apple.com"
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"


def token() -> str:
    key = open(os.environ["ASC_KEY_PATH"]).read()
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
                      key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


def get(path: str, params: dict | None = None) -> dict:
    url = path if path.startswith("http") else API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token()}"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def all_pages(path: str, params: dict) -> tuple[list, list]:
    data, included, page = [], [], get(path, params)
    while True:
        data += page.get("data", [])
        included += page.get("included", [])
        nxt = page.get("links", {}).get("next")
        if not nxt or len(data) >= 200:
            return data, included
        page = get(nxt)


def main() -> None:
    os.makedirs(f"{OUT}/shots", exist_ok=True)
    apps = get("/v1/apps", {"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        sys.exit("앱을 찾지 못했다")
    app_id = apps[0]["id"]
    report = {}
    for kind in ["betaFeedbackScreenshotSubmissions", "betaFeedbackCrashSubmissions"]:
        try:
            data, included = all_pages(f"/v1/apps/{app_id}/{kind}", {"limit": 50, "sort": "-createdDate", "include": "build"})
        except urllib.error.HTTPError as e:
            print(f"{kind}: HTTP {e.code}")
            report[kind] = {"error": e.code}
            continue
        builds = {b["id"]: b["attributes"].get("version") for b in included if b["type"] == "builds"}
        items = []
        for d in data:
            a = d["attributes"]
            b = (d.get("relationships", {}).get("build", {}) or {}).get("data") or {}
            item = {"id": d["id"], "created": a.get("createdDate"), "build": builds.get(b.get("id")),
                    "comment": a.get("comment"), "device": a.get("deviceModel"), "os": a.get("osVersion"),
                    "shots": []}
            for i, s in enumerate(a.get("screenshots") or []):
                name = f"shots/{d['id']}_{i}.png"
                try:
                    urllib.request.urlretrieve(s["url"], f"{OUT}/{name}")
                    item["shots"].append(name)
                except Exception as e:  # 만료된 링크 등
                    item["shots"].append(f"download failed: {type(e).__name__}")
            items.append(item)
        report[kind] = items
        print(f"{kind}: {len(items)}건")
    json.dump(report, open(f"{OUT}/feedback.json", "w"), ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
