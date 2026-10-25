export class AppError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export function notFound(_request, _response, next) {
  next(new AppError(404, 'NOT_FOUND', 'The requested resource was not found.'));
}

export function errorHandler(error, _request, response, _next) {
  const status = error.status ?? 500;
  const code = error.code ?? 'INTERNAL_ERROR';
  if (status >= 500) _request.log?.error(error);
  response.status(status).json({
    error: {
      code,
      message: status >= 500 ? 'An unexpected server error occurred.' : error.message,
      ...(error.details ? { details: error.details } : {}),
    },
  });
}
