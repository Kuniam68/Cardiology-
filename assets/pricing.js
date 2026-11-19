import {decimalToMinor,minorToDecimal} from './money.js?v=academy-review-1';
import {client,currentUser} from './auth.js?v=academy-review-1';

const form=document.getElementById('pricing-form');
const notice=document.getElementById('pricing-status');
function tell(message,error=false){
  notice.textContent=message;
  notice.classList.toggle('error',error);
}
async function start(){
  const c=await client();
  if(!await currentUser())throw new Error('Sign in as an academy administrator.');
  const admin=await c.rpc('is_academy_admin');
  if(admin.error||!admin.data)throw new Error('Administrator access required.');
  const fields=form.elements,save=form.querySelector('button[type=submit]');
  form.querySelector('fieldset').disabled=false;
  let loadedId=null,wasPaid=false,version=0;
  function invalidate(){
    version++;
    loadedId=null;
    save.disabled=true;
  }
  fields.course.oninput=invalidate;
  invalidate();
  async function loadPrices(){
    invalidate();
    const request=version,id=fields.course.value.trim();
    if(!fields.course.reportValidity())return;
    try{
      const [prices,setting,course]=await Promise.all([
        c.from('payment_prices').select('currency,amount_minor,provisional').eq('course_id',id),
        c.from('payment_course_settings').select('paid').eq('course_id',id).maybeSingle(),
        c.from('academy_courses').select('id').eq('id',id).maybeSingle()
      ]);
      if(request!==version)return;
      if(prices.error||setting.error||course.error||!course.data)throw new Error('Choose an existing managed course and reload.');
      loadedId=id;
      fields.paid.checked=wasPaid=setting.data?.paid===true;
      fields.provisional.checked=!prices.data.length||prices.data.some(p=>p.provisional);
      for(const code of ['BDT','USD']){
        const row=prices.data.find(p=>p.currency===code);
        fields[code].value=row?.amount_minor?minorToDecimal(Number(row.amount_minor)):'';
      }
      save.disabled=false;
      tell('Independent prices loaded. Existing orders retain their recorded amounts.');
    }catch(error){tell(error.message,true);}
  }
  document.getElementById('load-prices').onclick=loadPrices;
  form.onsubmit=async event=>{
    event.preventDefault();
    if(!loadedId||loadedId!==fields.course.value.trim())return;
    if(wasPaid&&!fields.paid.checked&&!window.confirm('Make this course free? Published lesson text and quizzes will become publicly readable.'))return;
    save.disabled=true;
    try{
      const value=code=>fields[code].value.trim()?decimalToMinor(fields[code].value.trim()):null;
      const {error}=await c.rpc('academy_configure_prices',{course_key:loadedId,is_paid:fields.paid.checked,display_only:fields.provisional.checked,price_bdt:value('BDT'),price_usd:value('USD')});
      if(error)throw error;
      wasPaid=fields.paid.checked;
      tell('Course pricing saved.');
    }catch(error){tell(error.message,true);}finally{save.disabled=loadedId!==fields.course.value.trim();}
  };
  fields.course.value=new URLSearchParams(location.search).get('course')||'';
  if(fields.course.value)await loadPrices();
}
if(form)start().catch(error=>tell(error.message,true));
