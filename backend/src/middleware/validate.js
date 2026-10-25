import { AppError } from './errors.js';

export function validate(schema) {
  return (request, _response, next) => {
    const result = schema.safeParse(request.body);
    if (!result.success) {
      return next(new AppError(400, 'VALIDATION_ERROR', 'The request body is invalid.', result.error.flatten()));
    }
    request.body = result.data;
    return next();
  };
}
