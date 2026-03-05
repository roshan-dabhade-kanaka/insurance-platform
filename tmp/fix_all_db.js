const { Client } = require('pg');
const client = new Client({
    host: 'localhost',
    port: 5432,
    user: 'postgres',
    password: 'password',
    database: 'insurance_db'
});

async function run() {
    await client.connect();
    const fields = [
        { fieldName: 'sumInsured', label: 'Sum Insured', type: 'number', required: true },
        { fieldName: 'policyTerm', label: 'Policy Term', type: 'dropdown', options: [10, 20, 30], required: true },
        { fieldName: 'dateOfBirth', label: 'Date of Birth', type: 'date', required: true }
    ];

    // Update all versions that have empty fields
    const res = await client.query(
        "UPDATE product_versions SET quote_fields = $1, status = 'ACTIVE' WHERE quote_fields = '[]'::jsonb",
        [JSON.stringify(fields)]
    );

    console.log('Update result:', res.rowCount, 'versions updated.');
    await client.end();
}

run().catch(e => {
    console.error(e);
    process.exit(1);
});
