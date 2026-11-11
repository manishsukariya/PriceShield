/**
 * Utility script to bulk-import products into PriceShield PostgreSQL database.
 * Supports:
 * - JSON files containing product arrays ([{ barcode, name, mrp }, ...])
 * - Open Food Facts JSON export lines
 * 
 * Usage:
 *   node scripts/import-open-products.js ./path/to/dataset.json
 */

import fs from 'node:fs';
import path from 'node:path';
import { PrismaClient } from '@prisma/client';
import { extractProductMrp, formatProductName } from '../src/modules/products/open-food-facts.js';

const prisma = new PrismaClient();

async function importFromFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(1);
  }

  console.log(`Reading dataset from: ${filePath}...`);
  const raw = fs.readFileSync(filePath, 'utf8');
  let products = [];

  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) {
      products = parsed;
    } else if (Array.isArray(parsed.products)) {
      products = parsed.products;
    }
  } catch {
    // Attempt line-delimited JSON (JSONL)
    const lines = raw.split('\n').filter((l) => l.trim().length > 0);
    for (const line of lines) {
      try {
        products.push(JSON.parse(line));
      } catch {
        // Skip invalid line
      }
    }
  }

  console.log(`Found ${products.length} candidate items. Processing and seeding...`);

  let count = 0;
  for (const item of products) {
    const barcode = (item.barcode || item.code || item._id || '').toString().trim();
    if (!barcode) continue;

    const name = item.name || formatProductName(item, barcode);
    const mrp = Number(item.mrp) || extractProductMrp(item);

    if (mrp <= 0) continue;

    try {
      await prisma.product.upsert({
        where: { barcode },
        update: { name, mrp },
        create: { barcode, name, mrp },
      });
      count++;
      if (count % 100 === 0) {
        console.log(`Imported ${count} products...`);
      }
    } catch (err) {
      // Continue on item error
    }
  }

  console.log(`Import complete! Successfully imported/updated ${count} products.`);
}

const targetPath = process.argv[2];
if (!targetPath) {
  console.log('Usage: node scripts/import-open-products.js <path-to-json-file>');
  console.log('Example: node scripts/import-open-products.js ./data/openfoodfacts-india.json');
  process.exit(0);
}

importFromFile(path.resolve(targetPath))
  .catch((err) => {
    console.error('Import failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
