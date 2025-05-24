require('dotenv').config();
const mysql = require('mysql2');
const util = require('util');

const db = mysql.createConnection({
    host: process.env.DB_HOST || 'server.sparkvtc.com',
    user: process.env.DB_USER || 'aquauser',
    password: process.env.DB_PASS || '98nWVQAYUDuJ-Eal',
    database: process.env.DB_NAME || 'aquafocus'
});

db.connect((err) => {
    if (err) {
        console.error('MySQL Connection Error:', err);
        return;
    }
    console.log('MySQL Successfully Connected');
});

// Promisify db.query
db.query = util.promisify(db.query);

module.exports = db;