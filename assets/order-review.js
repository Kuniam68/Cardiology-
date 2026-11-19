// A review lives only in this document. No billing data is sent or persisted.
export function installReview(root, prices, title) {
  const form = root.querySelector('#checkout-form');
  const currency = root.querySelector('#checkout-currency');
  const summary = root.querySelector('#review-result');
  const valid = prices.filter(p => ['BDT','USD'].includes(p.currency) &&
    Number.isSafeInteger(p.amountMinor) && p.amountMinor > 0 && p.amountMinor <= 1000000000);
  const find = () => valid.find(p => p.currency === currency.value);
  const format = p => (p.currency === 'BDT' ? '৳' : '$') + (p.amountMinor / 100).toFixed(2);
  for (const option of currency.options) option.disabled = !valid.some(p => p.currency === option.value);
  currency.disabled = !valid.length;
  if (valid.length && !find()) currency.value = valid[0].currency;
  function refresh() {
    const price = find();
    root.querySelector('#display-label').textContent = currency.value + ' display price';
    root.querySelector('.checkout-total').textContent = price ? format(price) : 'Price unavailable';
    root.querySelector('#price-stage').textContent = price?.provisional ? 'Provisional display price' : '';
    if(currency.value==='USD') root.querySelector('#pay-button').disabled=true;
    else root.querySelector('#pay-button').disabled=form.dataset.payable!=='true';
    summary.hidden=true;
  }
  refresh();
  currency.addEventListener('change', refresh);
  form.addEventListener('input', () => { summary.hidden = true; });
  root.querySelector('#review-button').disabled = !valid.length;
  for(const field of form.querySelectorAll('input[type=text]'))field.pattern='.*\\S.*';
  form.addEventListener('submit', event => {
    if (event.submitter?.id==='pay-button') return;
    event.preventDefault();
    event.stopImmediatePropagation();
    const price = find();
    if (!price || !form.reportValidity()) return;
    const values = new FormData(form);
    const billing = ['name','phone','address','city','postcode','country'].map(key=>String(values.get(key)||'').trim());
    if (billing.some(v=>!v)) {summary.textContent='Complete all billing fields before reviewing.';}
    else summary.textContent = [title, price.currency+' '+format(price)+(price.provisional?' · provisional':''), ...billing,
      'Review only. No order, charge or enrollment has been created.'].join('\n');
    summary.hidden=false;
    summary.focus();
  },true);
}
