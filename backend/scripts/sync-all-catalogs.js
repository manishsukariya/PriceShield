import fs from 'node:fs';
import path from 'node:path';

const curatedPath = path.resolve('backend/data/curated_indian_fmcg_catalog.json');
const curated = JSON.parse(fs.readFileSync(curatedPath, 'utf8'));

// 1. Read existing seed.js
const seedPath = path.resolve('backend/prisma/seed.js');
let seedContent = fs.readFileSync(seedPath, 'utf8');

// 2. Read existing default_products_catalog.dart
const dartPath = path.resolve('lib/core/data/default_products_catalog.dart');
let dartContent = fs.readFileSync(dartPath, 'utf8');

let addedToSeed = 0;
let addedToDart = 0;

for (const item of curated) {
  // Check if barcode already exists in seed.js
  if (!seedContent.includes(`barcode: '${item.barcode}'`)) {
    const formatted = `  { barcode: '${item.barcode}', name: "${item.name.replace(/"/g, '\\"')}", mrp: ${Number(item.mrp).toFixed(2)} },\n`;
    seedContent = seedContent.replace(/\];\s*\n\s*export async function seedProducts/, `${formatted}];\n\nexport async function seedProducts`);
    addedToSeed++;
  }

  // Check if barcode already exists in default_products_catalog.dart
  if (!dartContent.includes(`'${item.barcode}': {`)) {
    const formattedDart = `  '${item.barcode}': {\n    'barcode': '${item.barcode}',\n    'name': "${item.name.replace(/"/g, '\\"')}",\n    'mrp': ${Number(item.mrp).toFixed(2)},\n  },\n`;
    dartContent = dartContent.replace(/};\s*$/, `${formattedDart}};`);
    addedToDart++;
  }
}

fs.writeFileSync(seedPath, seedContent, 'utf8');
fs.writeFileSync(dartPath, dartContent, 'utf8');

console.log(`Sync complete! Added ${addedToSeed} new items to backend seed.js and ${addedToDart} new items to Flutter default_products_catalog.dart.`);
