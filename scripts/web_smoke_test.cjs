const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.BROWSER_PATH,args:['--no-sandbox']});
 const context=await browser.newContext();const page=await context.newPage();const errors=[];const external=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',route=>{if(!route.request().url().startsWith('http://127.0.0.1:8874')){external.push(route.request().url());return route.abort()}return route.continue()});
 const enable=async()=>{await page.locator('flt-semantics-placeholder').evaluate(e=>e.click()); await page.getByText('Nouvelle tâche',{exact:true}).waitFor()};
 await page.goto('http://127.0.0.1:8874');await enable();
 await context.setOffline(true);
 await page.getByText('Nouvelle tâche',{exact:true}).click();
 await page.getByRole('textbox',{name:'Que faut-il faire ?',exact:true}).fill('Test Web persistant');
 await page.getByRole('textbox',{name:'Lieu',exact:true}).click(); await page.waitForTimeout(200); await page.keyboard.type('Paris'); await page.keyboard.press('Tab');
 await page.getByText('Enregistrer',{exact:true}).click();
 await page.getByText(/^Test Web persistant/).waitFor();
 await page.waitForTimeout(500);
 await context.setOffline(false);await page.reload();await enable();
 await page.getByText(/^Test Web persistant/).waitFor();
 await page.getByText(/^Test Web persistant/).click();
 await page.getByText('Modifier la tâche',{exact:true}).click(); await page.getByRole('textbox',{name:'Lieu',exact:true}).waitFor(); await page.getByRole('textbox',{name:'Lieu',exact:true}).click(); await page.waitForTimeout(200); assert.equal(await page.getByRole('textbox',{name:'Lieu',exact:true}).inputValue(),'Paris');
 assert.deepEqual(errors,[]);assert.deepEqual(external,[]);

 console.log('PASS: startup, offline creation, IndexedDB reload, location details; no external resources or JavaScript errors.');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
