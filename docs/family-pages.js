const pageLanguageKey="foxly-motd-language";
function setPageLanguage(language,persist=true){
  document.documentElement.lang=language;
  document.querySelectorAll("[data-de][data-en]").forEach((element)=>{element.innerHTML=element.dataset[language]});
  document.querySelectorAll(".lang-button").forEach((button)=>button.classList.toggle("active",button.dataset.language===language));
  const body=document.body;
  document.title=body.dataset[`title${language==="de"?"De":"En"}`]||document.title;
  const description=document.querySelector('meta[name="description"]');
  if(description&&body.dataset[`description${language==="de"?"De":"En"}`])description.content=body.dataset[`description${language==="de"?"De":"En"}`];
  if(persist)localStorage.setItem(pageLanguageKey,language);
}
document.querySelectorAll(".lang-button").forEach((button)=>button.addEventListener("click",()=>setPageLanguage(button.dataset.language)));
document.getElementById("copyright-year").textContent=new Date().getFullYear();
setPageLanguage(localStorage.getItem(pageLanguageKey)||(navigator.language.toLowerCase().startsWith("de")?"de":"en"),false);
