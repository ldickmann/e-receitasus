import 'package:supabase_flutter/supabase_flutter.dart';

class PrescriptionService {
  final _supabase = Supabase.instance.client;

  // Stream para Sincronização em Tempo Real (Ponto IV do Adendo Acadêmico)
  Stream<List<Map<String, dynamic>>> streamPrescriptions() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return const Stream.empty();

    return _supabase
        .from('Prescription') // Nome da tabela que criamos no Prisma
        .stream(primaryKey: ['id'])
        .eq('patientId', myId)
        .order('createdAt', ascending: false);
  }
}
