import { AppError } from '../middleware/errors.js';

export function parseLimit(value, defaultValue = 20) {
  if (value === undefined) return defaultValue;
  const limit = Number(value);
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new AppError(400, 'VALIDATION_ERROR', 'limit must be an integer between 1 and 100.');
  }
  return limit;
}

export function parseCursor(value) {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || value.trim().length < 1 || value.length > 191) {
    throw new AppError(400, 'VALIDATION_ERROR', 'cursor must be a valid record identifier.');
  }
  return value.trim();
}

export function pageResult(records, limit) {
  const hasMore = records.length > limit;
  const data = hasMore ? records.slice(0, limit) : records;
  return {
    data,
    meta: { nextCursor: hasMore ? data.at(-1).id : null },
  };
}
