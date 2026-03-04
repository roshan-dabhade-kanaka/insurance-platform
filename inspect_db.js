const { Client } = require('pg');
const client = new Client({ connectionString: 'postgresql://postgres:password@localhost:5432/insurance_db' });
client.connect().then(async () => {
    const tables = ['insurance_products', 'product_versions', 'coverage_options', 'risk_profiles'];
    for (const table of tables) {
        const cols = await client.query('SELECT column_name FROM information_schema.columns WHERE table_name = $1', [table]);
        console.log(table.toUpperCase() + ' COLUMNS:', cols.rows.map(r => r.column_name));
        const data = await client.query(`SELECT * FROM ${table} LIMIT 5`);
        console.log(table.toUpperCase() + ' DATA:', JSON.stringify(data.rows, null, 2));
    }
    client.end();
}).catch(e => {
    console.error(e);
    process.exit(1);
});
