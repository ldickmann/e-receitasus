import type { NextFunction, Request, Response } from 'express';

/**
 * Middleware de logging de requisicoes HTTP no padrao de boas praticas REST.
 *
 * Loga: timestamp ISO, metodo, path, status, duracao em ms, content-length.
 * Usa console.log para 2xx/3xx, console.warn para 4xx, console.error para 5xx.
 *
 * Nao loga corpo, headers de Authorization, cookies ou query params com PII —
 * conformidade LGPD para um sistema de saude.
 */
export function requestLogger(req: Request, res: Response, next: NextFunction): void {
  const startNs = process.hrtime.bigint();
  const { method, originalUrl } = req;

  // Em produ\u00e7\u00e3o real, troque por structured logging (pino, winston).
  // Para MVP, console nativo cobre observabilidade local sem dependencia extra.
  res.on('finish', () => {
    // Calcula dura\u00e7\u00e3o em ms com precis\u00e3o de microssegundo
    const durationMs = Number(process.hrtime.bigint() - startNs) / 1_000_000;
    const status = res.statusCode;
    const length = res.getHeader('content-length') ?? '-';
    const timestamp = new Date().toISOString();

    const line = `[${timestamp}] ${method} ${originalUrl} ${status} ${durationMs.toFixed(1)}ms (${length}b)`;

    // Roteia o nivel pelo status para facilitar grep/alertas
    if (status >= 500) {
      console.error(line);
    } else if (status >= 400) {
      console.warn(line);
    } else {
      console.log(line);
    }
  });

  next();
}
