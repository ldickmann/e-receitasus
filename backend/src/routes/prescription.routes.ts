import { Router } from 'express';
import { createPrescription, getPrescriptions } from '../controllers/prescription.controller.js';

const router = Router();

// Rota POST /prescriptions
router.post('/', createPrescription);

// Rota GET /prescriptions
router.get('/', getPrescriptions);

export default router;