# 나고야 가족 여행 페이지 (2026.12.27–12.31)

이 저장소는 가족끼리만 보는 여행 동선 페이지예요. GitHub Pages로 공개되지만 **내용은 모두 비밀번호로 암호화**돼 있어요.

- 사이트: https://alexhjlim10.github.io/trip-pngxmtmwpw/
- `index.html`: 비밀번호 입력 화면 (브라우저에서 `data.bin`을 복호화해 보여 줌)
- `data.bin`: 암호화된 완성 페이지
- `src.enc`: 암호화된 원본 (`template.html`, `script.js`)
- `build/`: 공개해도 되는 재료 (지도 타일 `tiles.json`, Leaflet)
- `tool.js`: 풀기·만들기·암호화 도구 (Node 18+, 외부 패키지 없음)
- `secrets.enc`: 암호화된 키 (Claude API 키·GitHub 토큰). 사이트의 "Claude에게 요청"과 가족 공용 저장에 씀. `set_keys.ps1`(키_설정하기.bat)로만 만든다
- `shared.enc`: 암호화된 가족 공용 일정 설정(날짜 고정·지점·켜고 끄기·시간). 사이트가 직접 저장·읽음. 기본 일정(script.js)보다 우선 적용됨

## 규칙 (중요)
1. **비밀번호는 사용자에게 물어서 받는다.** 저장소, 커밋 메시지, 파일 어디에도 비밀번호를 적지 않는다.
2. **평문을 커밋하지 않는다.** `work/`, `out/`, `source/`는 `.gitignore`에 있다. 커밋 전에 `git status`로 `data.bin`, `src.enc` 외의 일정 내용이 올라가지 않는지 확인한다.
3. 비공개·비상업용 가족 페이지다. 공개 홍보나 상업적 사용으로 바꾸지 않는다.

## 수정하는 순서
```bash
export NAGOYA_PW='사용자가 알려 준 비밀번호'
node tool.js unpack          # work/template.html, work/script.js 생성
# work/script.js 수정 (아래 참고)
node tool.js build           # 문법 검사 → out/, data.bin, src.enc 갱신
node tool.js check           # 새 파일이 비밀번호로 열리는지 확인
git add data.bin src.enc && git commit -m "..." && git push
```
push 후 1~2분 뒤 사이트에 반영된다. 이미 열어 둔 폰은 새로고침하면 된다.

## script.js 구조
- `PLACES`: 가고 싶은 곳 목록. 항목 하나 = `{ id, no, name, cat, meal?, dur(분), links?, rec?, opts: [...] }`
  - `opts`: 같은 항목의 지점·가게 후보. `O(이름, 구글평점, 리뷰수, 위도, 경도, place_id, { h: 영업시간, cl: 휴무일, sp: 특별영업, note, alt })`
  - `alt: 1`: 다른 브랜드·종류라서 자동 선택에서 빼는 후보 (지도·대안 목록에는 보임)
  - `meal`: `["lunch","dinner"]` 식사 시간대, `"snack"` 오후 간식
  - `rec: true`: 추천 장소 (기본 꺼짐)
  - 영업시간 `H("11:00","20:00")`, 휴무 `cl: ["12-30"]`, 12/31 단축 `sp: NYE`
- `DAYS`: 날짜별 기본 출발·귀가 시간
- `KONBINI`: 편의점 목록 (매일 마지막에 가까운 곳 10분)
- `LINKS`: 티켓·쿠폰 등 공식 링크
- 동선 계산: `evalDay`(하루 비용: 이동 시간 ×3, 걷는 거리, 영업시간, 식사 시간대) → `solveDay`(순서 최적화) → `plan`(날짜·지점 배정)

## 새 장소를 추가할 때
1. 장소의 정확한 위치(위도·경도)와 Google 평점·리뷰 수를 확인한다. 모르면 사용자에게 알리고 값을 `null`로 둔다.
2. 사용자 가족은 **오래 걷기 힘들다.** 숙소(사카에)나 나고야역에서 너무 먼 곳은 추가 전에 사용자에게 확인한다.
3. `PLACES`에 항목을 추가하고 build → check → push.
4. 사용자에게 바뀐 날짜별 코스를 짧게 알려 준다.

## 비밀번호 바꾸기
```bash
node tool.js repass '옛비밀번호' '새비밀번호' && git add data.bin src.enc && git commit -m "Change password" && git push
```
