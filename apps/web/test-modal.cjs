const { chromium } = require('playwright');
(async()=>{
 const browser=await chromium.launch({headless:true});
 const page=await browser.newPage({viewport:{width:390,height:1100}});
 const errors=[];
 page.on('console',m=>{ if(m.type()==='error') errors.push(m.text()); });
 await page.goto('http://158.247.227.250:8083/',{waitUntil:'networkidle'});
 const buttons=page.locator('.location-actions button');
 console.log('actions=',await buttons.count(), await buttons.allTextContents());
 await buttons.nth(1).click();
 await page.waitForTimeout(1500);
 await page.screenshot({path:'C:\\Users\\vuong\\Documents\\code\\sharee\\tools\\uicheck\\web-map-modal.png',fullPage:false});
 console.log('modal=',await page.locator('.map-modal').count(),'leaflet=',await page.locator('.leaflet-container').count(),'errors=',errors.slice(0,3));
 await browser.close();
})();
