import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';

/// Sino de notificações para a AppBar das telas-home.
///
/// Consome o [NotificationProvider] e exibe um contador (badge) com o número
/// de eventos não lidos recebidos via Supabase Realtime sobre `RenewalRequest`.
/// Tocar reconhece os eventos (zera o contador) — as listas da tela já se
/// atualizam sozinhas pelos seus próprios streams, então o sino é apenas o
/// indicador "há novidade" visível de relance.
///
/// Segue a convenção visual do projeto: badge manual com `Stack`/`Positioned`
/// (mesmo padrão do contador de "Renovações Pendentes" do médico), sem
/// depender do widget `Badge` do Material.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.color});

  /// Cor do ícone — combina com o `foregroundColor` da AppBar de cada perfil.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Consumer cirúrgico: só este botão reconstrói quando o contador muda,
    // sem rebuild do restante da AppBar/tela.
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final count = provider.unreadCount;
        final hasUnread = count > 0;

        return IconButton(
          tooltip: hasUnread
              ? '$count atualização(ões) em tempo real'
              : 'Notificações',
          // markAllRead é no-op quando não há não lidas — botão sempre ativo.
          onPressed: provider.markAllRead,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                hasUnread
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: color,
              ),
              if (hasUnread)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}