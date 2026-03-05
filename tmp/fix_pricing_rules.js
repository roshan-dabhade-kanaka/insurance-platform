const { Client } = require('pg');

const client = new Client({
    host: 'localhost',
    port: 5432,
    user: 'postgres',
    password: 'password',
    database: 'insurance_db'
});

async function fixPricingRules() {
    await client.connect();
    console.log('Connected to DB');

    // Fix "Basic Premium Calculation" which was missing 'factors' and 'baseRate'
    // and had a json-rules-engine structure instead
    const basicRule = {
        baseRate: 2500,
        factors: [],
        minimumPremium: 1000,
        maximumPremium: 1000000
    };

    // Fix "General" rule which had lowercase 'multiplier' and incorrect 'values' map
    const generalRule = {
        baseRate: 500,
        factors: [
            {
                name: "smoker_loading",
                type: "MULTIPLIER",
                fact: "smoker",
                operator: "equal",
                value: true,
                adjustment: 1.5,
                direction: "INCREASE"
            }
        ]
    };

    try {
        const res1 = await client.query(
            `UPDATE pricing_rules SET rule_expression = $1 WHERE name = 'Basic Premium Calculation'`,
            [JSON.stringify(basicRule)]
        );
        console.log(`Updated 'Basic Premium Calculation': ${res1.rowCount} row(s)`);

        const res2 = await client.query(
            `UPDATE pricing_rules SET rule_expression = $1 WHERE name = 'General'`,
            [JSON.stringify(generalRule)]
        );
        console.log(`Updated 'General': ${res2.rowCount} row(s)`);

    } catch (err) {
        console.error('Error updating rules:', err);
    } finally {
        await client.end();
    }
}

fixPricingRules();
