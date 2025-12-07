import { Router } from 'express';
import { getHistory } from '../controllers/history.controller.js';

const router = Router();

router.get('/', getHistory);

export default router;