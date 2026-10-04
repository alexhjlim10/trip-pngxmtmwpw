#!/usr/bin/env node
// 나고야 여행 페이지 관리 도구 (Node 18+, 외부 패키지 없음)
//
//   NAGOYA_PW=비밀번호 node tool.js unpack        src.enc → work/ (일정 원본 풀기)
//   NAGOYA_PW=비밀번호 node tool.js build         work/ → out/, data.bin, src.enc (다시 만들고 암호화)
//   NAGOYA_PW=비밀번호 node tool.js check         data.bin·src.enc가 이 비밀번호로 열리는지 확인
//   node tool.js repass 옛비밀번호 새비밀번호      data.bin·src.enc 비밀번호 바꾸기
//
// 암호화 형식 (index.html의 복호화 코드와 같아야 함):
//   salt(16) | iv(16) | AES-256-CBC(PBKDF2-SHA256 250000회, PKCS7) of ("NGYOK:" + 본문)
"use strict";
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const vm = require("vm");

const ROOT = __dirname;
const P = (...a) => path.join(ROOT, ...a);
const MARK = "NGYOK:";
const ITER = 250000;

function encrypt(text, pw) {
  const salt = crypto.randomBytes(16), iv = crypto.randomBytes(16);
  const key = crypto.pbkdf2Sync(pw, salt, ITER, 32, "sha256");
  const c = crypto.createCipheriv("aes-256-cbc", key, iv);
  const ct = Buffer.concat([c.update(Buffer.from(MARK + text, "utf8")), c.final()]);
  return Buffer.concat([salt, iv, ct]);
}
function decrypt(buf, pw) {
  const salt = buf.subarray(0, 16), iv = buf.subarray(16, 32), ct = buf.subarray(32);
  const key = crypto.pbkdf2Sync(pw, salt, ITER, 32, "sha256");
  let out;
  try { const d = crypto.createDecipheriv("aes-256-cbc", key, iv); out = Buffer.concat([d.update(ct), d.final()]).toString("utf8"); }
  catch (e) { throw new Error("비밀번호가 맞지 않아요 (복호화 실패)"); }
  if (!out.startsWith(MARK)) throw new Error("비밀번호가 맞지 않아요 (확인 문자 불일치)");
  return out.slice(MARK.length);
}
function pw() {
  const v = process.env.NAGOYA_PW;
  if (!v) { console.error("NAGOYA_PW 환경변수로 비밀번호를 넘겨 주세요. 예) NAGOYA_PW=... node tool.js build"); process.exit(2); }
  return v;
}

// 아티팩트용 페이지: template.html의 표시 자리에 Leaflet CSS, 지도 타일, script.js를 끼워 넣음
function buildPage(template, script, leafletCss, tiles) {
  const lines = template.split("\n");
  const ti = lines.findIndex(l => l.startsWith("window.TILES"));
  if (ti < 0) throw new Error("template.html에서 window.TILES 줄을 찾지 못했어요");
  const head = lines.slice(0, ti).map(l => l.includes("/*@@LEAFLET_CSS@@*/") ? leafletCss : l).join("\n");
  return head + "\nwindow.TILES = " + tiles + ";\n</script>\n<script>\n" + script + "</script>\n";
}
// 폰·사이트용 단독 페이지: 문서 뼈대를 씌우고 Leaflet 스크립트를 파일 안에 넣음
function standalone(page, leafletJs) {
  const tag = '<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.js"></script>';
  if (!page.includes(tag)) throw new Error("Leaflet script 태그를 찾지 못했어요");
  const body = page.replace(tag, () => "<script>\n" + leafletJs + "\n</script>");
  return '<!doctype html>\n<html lang="ko"><head><meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}[hidden]{display:none!important}img{max-width:100%}</style>\n</head><body>\n' + body + "\n</body></html>\n";
}

const cmd = process.argv[2];
process.on("uncaughtException", e => { console.error("오류: " + e.message); process.exit(1); });
if (cmd === "unpack") {
  const files = JSON.parse(decrypt(fs.readFileSync(P("src.enc")), pw()));
  fs.mkdirSync(P("work"), { recursive: true });
  for (const [name, text] of Object.entries(files)) fs.writeFileSync(P("work", name), text);
  console.log("풀었어요: work/" + Object.keys(files).join(", work/"));
} else if (cmd === "build") {
  const password = pw();
  const template = fs.readFileSync(P("work", "template.html"), "utf8");
  const script = fs.readFileSync(P("work", "script.js"), "utf8");
  try { new vm.Script(script, { filename: "work/script.js" }); }
  catch (e) { console.error("script.js 문법 오류: " + e.message); process.exit(1); }
  // 기존 비밀번호와 같은지 확인 (실수로 다른 비밀번호로 덮어쓰지 않게)
  decrypt(fs.readFileSync(P("data.bin")), password);
  const page = buildPage(template, script, fs.readFileSync(P("build", "leaflet.css"), "utf8"), fs.readFileSync(P("build", "tiles.json"), "utf8"));
  const single = standalone(page, fs.readFileSync(P("build", "leaflet.js"), "utf8"));
  fs.mkdirSync(P("out"), { recursive: true });
  fs.writeFileSync(P("out", "nagoya.html"), page);
  fs.writeFileSync(P("out", "nagoya_trip.html"), single);
  fs.writeFileSync(P("data.bin"), encrypt(single, password));
  fs.writeFileSync(P("src.enc"), encrypt(JSON.stringify({ "template.html": template, "script.js": script }), password));
  console.log("만들었어요: data.bin, src.enc, out/nagoya.html (claude.ai용), out/nagoya_trip.html (폰 파일용)");
} else if (cmd === "check") {
  const password = pw();
  const html = decrypt(fs.readFileSync(P("data.bin")), password);
  const files = JSON.parse(decrypt(fs.readFileSync(P("src.enc")), password));
  console.log("OK: data.bin " + html.length + "자, src.enc 파일 " + Object.keys(files).join(", "));
} else if (cmd === "repass") {
  const [oldPw, newPw] = process.argv.slice(3);
  if (!oldPw || !newPw) { console.error("사용법: node tool.js repass 옛비밀번호 새비밀번호"); process.exit(2); }
  for (const f of ["data.bin", "src.enc"]) fs.writeFileSync(P(f), encrypt(decrypt(fs.readFileSync(P(f)), oldPw), newPw));
  console.log("비밀번호를 바꿨어요. git commit 후 push 하면 반영돼요.");
} else {
  console.log("사용법: node tool.js unpack | build | check | repass 옛 새   (unpack/build/check는 NAGOYA_PW 필요)");
  process.exit(cmd ? 2 : 0);
}
