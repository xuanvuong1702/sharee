const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch(); const p=await b.newPage({viewport:{width:390,height:1000}});
 await p.goto('http://158.247.227.250:8083/',{waitUntil:'networkidle'});
 const info=await p.locator('.search-card-head h2').evaluate(el=>({text:el.textContent,rect:el.getBoundingClientRect().toJSON(),color:getComputedStyle(el).color,display:getComputedStyle(el).display,font:getComputedStyle(el).fontSize}));
 console.log(info); await b.close();
})();
