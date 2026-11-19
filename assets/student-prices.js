import {minorToDecimal,MAX_MINOR} from './money.js?v=academy-review-1';

const codes=['BDT','USD'];
const validAmount=value=>Number.isSafeInteger(value)&&value>=1&&value<=MAX_MINOR;

export async function readStudentPrices(getClient,courseIds) {
  const ids=[...new Set(courseIds)];
  const prices=new Map(ids.map(id=>[id,{BDT:null,USD:null}]));
  if(!ids.length)return prices;
  if(ids.length>50){
    for(let i=0;i<ids.length;i+=50){
      const batch=await readStudentPrices(getClient,ids.slice(i,i+50));
      for(const [id,price] of batch)prices.set(id,price);
    }
    return prices;
  }
  const c=await getClient();
  // Public pricing fields only. RLS decides which published courses are visible.
  const {data,error}=await c.from('payment_prices')
    .select('course_id,currency,amount_minor,provisional').in('course_id',ids);
  if(error||!Array.isArray(data))throw new Error('Course prices are unavailable.');
  const seen=new Set(),pending=new Set(),duplicates=new Set();
  for(const row of data){
    if(!row||!prices.has(row.course_id)||!codes.includes(row.currency))continue;
    if(row.provisional===true)prices.get(row.course_id).provisional=true;
    const key=JSON.stringify([row.course_id,row.currency]);
    if(seen.has(key))duplicates.add(key);if(row.amount_minor===null)pending.add(key);
    const value=!seen.has(key)&&validAmount(row.amount_minor)?row.amount_minor:null;
    seen.add(key);
    prices.get(row.course_id)[row.currency]=value;
  }
  for(const id of ids)if(codes.every(code=>pending.has(JSON.stringify([id,code]))&&!duplicates.has(JSON.stringify([id,code])))&&!hasAvailablePrice(prices.get(id)))prices.get(id).pendingApproval=true;
  return prices;
}

export const hasAvailablePrice=prices=>codes.some(code=>validAmount(prices?.[code]));

export function studentPriceSummary(prices,{paid,verified=true,checkoutEnabled=false}) {
  if(!paid)return '';
  const amounts=codes.map(code=>{
    const amount=verified?prices?.[code]:null;
    const text=validAmount(amount)?(code==='BDT'?'৳':'$')+minorToDecimal(amount):verified&&prices?.pendingApproval===true?'Awaiting owner approval':'Price unavailable';
    return `<p><strong>${code}</strong> <span>${text}</span></p>`;
  }).join('');
  return `<div class="course-prices" aria-label="Course prices">${amounts}${prices?.provisional?'<p>Provisional pricing · USD for information only</p>':''}${checkoutEnabled?'':'<p class="notice">Payments unavailable · checkout disabled</p>'}</div>`;
}
