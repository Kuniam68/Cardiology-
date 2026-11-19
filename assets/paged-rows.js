// Callers supply a stable unique ordering for every page.
export async function pagedRows(buildQuery) {
  const rows = [];
  const batch = 100;
  for (;;) {
    const {data,error} = await buildQuery().range(rows.length,rows.length+batch-1);
    if(error || !Array.isArray(data)) throw new Error('Records could not be loaded.');
    rows.push(...data);
    if(data.length < batch) return rows;
  }
}
