import { Router } from 'express';
import type { Response } from 'express';
import { authenticateToken, type AuthRequest } from '../middlewares/auth.middleware.js';
import {
  HealthUnitServiceError,
  listHealthUnitsByCity,
} from '../services/healthUnit.service.js';

const router = Router();

/**
 * Tamanho maximo defensivo dos parametros de query.
 *
 * Por que esse limite? `city` em base IBGE costuma ter no maximo ~60 caracteres
 * (ex.: "Sao Joao do Itaperiu"). Aceitar strings absurdas vindas do cliente
 * abre porta para abuso (ReDoS, ataque de carga em LIKE). Cortamos cedo
 * para falhar rapido com 400 sem chegar ao banco.
 */
const MAX_CITY_LENGTH = 120;

/**
 * UF brasileira: exatamente 2 letras maiusculas. Validamos para evitar SQL
 * com lixo (ex.: "; DROP ...") mesmo sabendo que Prisma parametriza —
 * defesa em profundidade conforme OWASP A03 (Injection).
 */
const UF_REGEX = /^[A-Z]{2}$/;

/**
 * Endpoint para listagem de UBS filtradas por municipio.
 *
 * Decisao de design (cf. TASK #211): a tabela `health_units` NAO possui
 * `cityCode` (IBGE) hoje — apenas `city` (texto) e `state` (CHAR 2). A TASK
 * #213 menciona `cityCode` mas nao podemos honrar isso sem migration adicional;
 * por isso o contrato publico usa `city` + `state`. Ajustar quando/se a coluna
 * `city_code` for adicionada ao schema.
 *
 * Contrato:
 * - Auth: JWT Supabase obrigatorio (Bearer).
 * - Query: `city` (string, 1..MAX_CITY_LENGTH) + `state` opcional (UF 2 letras).
 * - 200: array de UBS (`id`, `name`, `district`, `city`, `state`).
 * - 400: parametros invalidos.
 * - 401/403: token ausente/invalido (tratado pelo middleware).
 * - 500: erro inesperado (sem vazar stack/detalhes).
 */
router.get(
  '/',
  authenticateToken,
  async (req: AuthRequest, res: Response): Promise<Response> => {
    // `req.query.city` pode ser string | string[] | ParsedQs — narrowing explicito.
    const rawCity = req.query.city;
    const rawState = req.query.state;

    // Rejeita arrays/objetos cedo: contrato exige string simples.
    if (typeof rawCity !== 'string') {
      return res.status(400).json({
        error: 'Parametros invalidos',
        message: 'O parametro "city" e obrigatorio e deve ser uma string.',
      });
    }

    if (rawCity.length > MAX_CITY_LENGTH) {
      // Limite imposto antes do trim para incluir whitespace abusivo na conta.
      return res.status(400).json({
        error: 'Parametros invalidos',
        message: `O parametro "city" excede o limite de ${MAX_CITY_LENGTH} caracteres.`,
      });
    }

    let normalizedState: string | undefined;
    if (typeof rawState === 'string' && rawState.trim().length > 0) {
      // Service ja faz uppercase, mas validamos a forma na borda da rota
      // para devolver 400 em vez de aceitar "SaoPaulo" e cair em consulta vazia.
      normalizedState = rawState.trim().toUpperCase();

      if (!UF_REGEX.test(normalizedState)) {
        return res.status(400).json({
          error: 'Parametros invalidos',
          message: 'O parametro "state" deve ser a sigla UF (2 letras).',
        });
      }
    } else if (rawState !== undefined && typeof rawState !== 'string') {
      // Captura state=array enviado por cliente malicioso/buggy.
      return res.status(400).json({
        error: 'Parametros invalidos',
        message: 'O parametro "state" deve ser uma string.',
      });
    }

    try {
      const units = await listHealthUnitsByCity(rawCity, normalizedState);
      return res.status(200).json(units);
    } catch (error) {
      if (error instanceof HealthUnitServiceError) {
        return res.status(error.statusCode).json({
          error: 'Falha ao listar UBS',
          message: error.message,
        });
      }

      // OWASP A05/LGPD: nao expor stack trace nem caminhos internos.
      // Logamos apenas a mensagem (sem PII no contexto desta rota — UBS publica).
      const message = error instanceof Error ? error.message : 'Erro desconhecido';
      console.error('[HealthUnitRoutes] Erro inesperado ao listar UBS:', message);

      return res.status(500).json({
        error: 'Erro interno',
        message: 'Nao foi possivel listar as UBS no momento.',
      });
    }
  }
);

export default router;
