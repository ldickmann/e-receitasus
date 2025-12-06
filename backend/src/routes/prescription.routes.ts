import { Router } from 'express';
import { createPrescription } from '../controllers/prescription.controller.js';

const router = Router();

// Rota POST /prescriptions
router.post('/', createPrescription);

export default router;