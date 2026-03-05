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

    // Update the version for "Term Life Insurance"
    const res = await client.query(
        'UPDATE product_versions SET quote_fields = $1, status = $2 WHERE id = $3',
        [JSON.stringify(fields), 'ACTIVE', 'e3d5cf1c-398e-4872-b3a2-71136fa848dd']
    );

    console.log('Update result:', res.rowCount);

    const verify = await client.query(
        'SELECT status, quote_fields FROM product_versions WHERE id = $1',
        ['e3d5cf1c-398e-4872-b3a2-71136fa848dd']
    );
    console.log('Verified state:', JSON.stringify(verify.rows[0]));

    await client.end();
}

run().catch(e => {
    console.error(e);
    process.exit(1);
});
