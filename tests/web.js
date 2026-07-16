const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const html = fs.readFileSync(path.join(root, "docs", "index.html"), "utf8");
const cname = fs.readFileSync(path.join(root, "docs", "CNAME"), "utf8").trim();
const installer = fs.readFileSync(path.join(root, "docs", "install.sh"), "utf8");

function check(condition, message) {
    if (!condition) throw new Error(message);
}

check(cname === "motd.foxly.de", "Unexpected CNAME");
check(html.includes("https://motd.foxly.de/install.sh"), "Install URL missing");
check(html.includes("foxly-it/foxly-motd"), "GitHub repository link missing");
check(html.includes('meta name="description"'), "Meta description missing");
check(html.includes('data-de='), "German website content missing");
check(html.includes('data-en='), "English website content missing");
check(html.includes('navigator.language'), "Automatic browser language selection missing");
check(html.includes("https://foxly.de/datenschutzerklaerung/"), "Privacy link missing");
check(html.includes("https://foxly.de/legal-notice/"), "Legal notice link missing");
check(html.includes('data-terminal="de"') && html.includes('data-terminal="en"'), "Bilingual terminal preview missing");
check((html.match(/class="rainbow"/g) || []).length === 2, "Rainbow HomeLab preview missing");
check(html.includes("/ /_/ / __ \\/ __ `__ \\/ _ \\/ /"), "HomeLab ASCII art missing");
check(html.includes("10.0.0.20/24") && html.includes("DNS-Server:"), "Network details missing from preview");
check(html.includes("Systemd-Dienste:") && html.includes("fehlerhaft: 0"), "Health details missing from preview");
check((html.match(/class="sysinfo-box"/g) || []).length === 2, "Framed system information preview missing");
check(html.includes("width:min(1200px") && html.includes("minmax(320px,.7fr) minmax(0,1.3fr)"), "Wide terminal layout missing");
check(html.includes("@media(max-width:1020px)"), "Wide terminal breakpoint missing");
check((html.match(/class="terminal-prompt"/g) || []).length === 2, "Terminal prompts missing");
check((html.match(/class="cursor" aria-hidden="true"/g) || []).length === 2, "Terminal cursors missing");
check(html.includes("@keyframes cursor-blink") && html.includes("prefers-reduced-motion:reduce"), "Accessible cursor animation missing");
check(html.includes("@keyframes terminal-settle") && html.includes("rotateY(-8deg) translateX(16px)"), "Terminal hover animation missing");
check(html.includes("(hover:hover) and (pointer:fine)"), "Terminal hover capability guard missing");
check(installer.includes("sha256sum"), "Bootstrap installer does not verify SHA-256");
check(!html.includes("http://"), "Insecure HTTP URL found");

console.log("Web checks passed.");
