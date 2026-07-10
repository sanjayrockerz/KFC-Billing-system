import pg from 'pg'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const { Client } = pg

const client = new Client({
  host: 'aws-1-ap-northeast-2.pooler.supabase.com',
  port: 6543,
  user: 'postgres.gfwejwzoqezpviddgcbl',
  password: 'qLd2PkO1xZfZbAlq',
  database: 'postgres',
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 30000,
})

try {
  await client.connect()
  console.log('Connected')
  const sql = fs.readFileSync(path.join(__dirname, 'supabase/migrations/20260710_0003_fix_duplicates_and_types.sql'), 'utf8')
  console.log('Running migration 3...')
  await client.query(sql)
  console.log('  OK')
  console.log('\nMigration 3 applied!')
  await client.end()
} catch (err) {
  console.error('Failed:', err.message)
  await client.end().catch(() => {})
  process.exit(1)
}
