import 'package:boutik_ecole/figma/live/missions.dart';
import 'package:flutter_test/flutter_test.dart';

/// H8 : une mission du serveur n'affiche ni répartition 30/40/30, ni commission 10 %, ni part étudiante 70 % inventées.
void main() {
  final row = {'id': 'm1', 'number': '#BR-1', 'title': 'Affiche', 'status': 'assigned', 'created_at': '2026-10-30T09:00:00Z'};

  test('mission réelle avec jalons : montants du serveur, commission et gain indisponibles', () {
    final m = Mission.fromServer(row, 80000, [
      {'position': 1, 'title': 'Esquisses', 'amount': 30000, 'status': 'validated'},
      {'position': 2, 'title': 'Final', 'amount': 50000, 'status': 'submitted'},
    ]);
    expect(m.knownAmountOf(0), 30000);
    expect(m.knownAmountOf(1), 50000);
    expect(m.fee, isNull);
    expect(m.studentEarned, isNull);
  });

  test('mission réelle sans jalon : aucun montant inventé', () {
    final m = Mission.fromServer(row, 100000, const []);
    for (var i = 0; i < 3; i++) {
      expect(m.knownAmountOf(i), isNull);
      expect(m.amountLabel(i), '—');
    }
    expect(m.pendingAmount, 0);
    expect(m.fee, isNull);
    expect(m.studentEarned, isNull);
  });

  test('aperçu hors connexion : estimation conservée', () {
    const m = Mission(id: '#X', kind: 'Démo', desc: '', total: 180000, date: '', released: 1);
    expect(m.fee, 18000);
    expect(m.knownAmountOf(0), 54000);
    expect(m.studentEarned, 37800);
  });
}
