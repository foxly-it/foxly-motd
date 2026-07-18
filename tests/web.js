const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const html = fs.readFileSync(path.join(root, "docs", "index.html"), "utf8");
const cname = fs.readFileSync(path.join(root, "docs", "CNAME"), "utf8").trim();
const installer = fs.readFileSync(path.join(root, "docs", "install.sh"), "utf8");
const inlineScripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(match => match[1]);

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
check(html.includes("[ NETZWERK ]") && html.includes("[ RESSOURCEN ]") && html.includes("[ SITZUNG ]") && html.includes("[ SYSTEMSTATUS ]") && html.includes("[ PAKET-UPDATES ]"), "Three-column German dashboard preview missing");
check(html.includes("[ NETWORK ]") && html.includes("[ RESOURCES ]") && html.includes("[ SESSION ]") && html.includes("[ SYSTEM HEALTH ]"), "Grouped English dashboard preview missing");
check((html.match(/class="terminal-dashboard"/g) || []).length === 2 && (html.match(/class="terminal-dashboard secondary"/g) || []).length === 2, "Grid-based terminal dashboard missing");
check((html.match(/class="terminal-card"/g) || []).length === 10, "Terminal dashboard cards missing");
check((html.match(/class="terminal-icon"/g) || []).length === 10 && html.includes("row-gap:.16em") && html.includes("margin-bottom:.32em"), "Terminal icon sizing or vertical rhythm missing");
check(!html.includes("⚙ Systemd"), "Fragile system-health glyph remains in preview");
check((html.match(/class="sysinfo-box"/g) || []).length === 2, "Framed system information preview missing");
check(html.includes("width:min(1400px") && html.includes("minmax(320px,.7fr) minmax(0,1.3fr)"), "Wide terminal layout missing");
check(html.includes("function fitTerminalPreview") && html.includes("pre.scrollWidth>viewport.clientWidth"), "Rendered terminal-width fitting missing");
check(html.includes("@media(max-width:1100px)"), "Wide terminal breakpoint missing");
check((html.match(/class="terminal-prompt"/g) || []).length === 2, "Terminal prompts missing");
check((html.match(/class="cursor" aria-hidden="true"/g) || []).length === 2, "Terminal cursors missing");
check(html.includes("@keyframes cursor-blink") && html.includes("prefers-reduced-motion:reduce"), "Accessible cursor animation missing");
check(html.includes("@keyframes terminal-settle") && html.includes("rotateY(-8deg) translateX(16px)"), "Terminal hover animation missing");
check(html.includes("(hover:hover) and (pointer:fine)"), "Terminal hover capability guard missing");
check(html.includes('id="configurator"') && html.includes('id="motd-configurator"'), "Visual configurator missing");
check(html.includes('id="assistant-preview"') && html.includes('aria-live="polite"'), "Accessible live preview missing");
check(html.includes('id="assistant-config"') && html.includes("copyAssistantConfig"), "Generated configuration output missing");
check(html.includes('id="cfg-frame"') && html.includes('id="cfg-package-names"') && html.includes('id="cfg-package-limit"'), "Appearance and package controls missing");
check(html.includes("SHOW_NETWORK=") && html.includes("SHOW_FRAME=") && html.includes("PACKAGE_NAME_LIMIT="), "Modular generated settings missing");
const widthHelpers = html.match(/function displayGraphemes[\s\S]*?(?=    function renderCardGrid)/);
check(widthHelpers, "Display-width helpers missing");
const widthChecks = new Function(`${widthHelpers[0]}; return [displayWidth("🌐 A"), displayWidth("⚙ A"), padDisplay("🌐", 4)];`)();
check(widthChecks[0] === 4 && widthChecks[1] === 3 && widthChecks[2] === "🌐  ", "Emoji-aware frame padding is incorrect");
check(html.includes('className="terminal-wide"') && html.includes("width:2ch"), "Fixed-width emoji rendering missing");
const fitHelper = html.match(/function fitTerminalPreview[\s\S]*?(?=    let fitRequest)/);
check(fitHelper, "Terminal fitting helper missing");
const fittedSize = new Function(`${fitHelper[0]}; let size; const pre={parentElement:{clientWidth:100},scrollWidth:130,style:{set fontSize(value){size=parseFloat(value);pre.scrollWidth=size*10}}}; fitTerminalPreview(pre); return size;`)();
check(fittedSize === 10, "Terminal fitting does not use the visible parent width");
check(html.includes("Existing values in /etc/default/foxly-motd are retained"), "Configuration migration notice missing");
inlineScripts.forEach(script => new Function(script));
check(installer.includes("sha256sum"), "Bootstrap installer does not verify SHA-256");
check(!html.includes("http://"), "Insecure HTTP URL found");

console.log("Web checks passed.");
