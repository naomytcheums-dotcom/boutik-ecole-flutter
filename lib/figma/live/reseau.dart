import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'console.dart';
import 'entreprise.dart';
import 'feedback.dart' show claimReasonLabels, claimReasons;
import 'finance.dart' show financePaymentsProvider, paymentState;
import 'store.dart' show fcfa;

/// Réseau d'établissements, vœux, lives, litiges et paiements déclarés : listes lues sur le serveur, chargement, état vide et erreur
/// explicites, aucune ligne de maquette hors démonstration. Les droits de lecture sont ceux des tables (RLS).

final institutionsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('institutions', 'name,short_name,kind,city,status', order: 'created_at'));
final departmentsListProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('departments', 'name,status,institutions(name)', order: 'name', ascending: true, eq: {'status': 'verified'}, limit: 500, publicRead: true));
final wishesListProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('wishes', 'title,description,price,threshold,duration_days,status', order: 'created_at', anyOf: ('status', ['approved', 'scheduled']), publicRead: true));
final livesListProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('scheduled_lives', 'title,starts_at,product_title,status', order: 'created_at', eq: {'status': 'scheduled'}, publicRead: true));
final claimsListProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('claims', 'reason,details,status,created_at', order: 'created_at'));

String institutionStatus(Object? s) => switch ('$s') { 'verified' => 'Vérifié', 'rejected' => 'Refusé', _ => 'Proposé' };
String institutionKind(Object? s) => switch ('$s') { 'universite_etat' => 'Université d’État', 'institut' => 'Institut', 'ecole' => 'École', 'prive' => 'Privé', _ => 'Autre' };
String claimStatus(Object? s) => switch ('$s') { 'answered' => 'Répondue', 'closed' => 'Clôturée', _ => 'Ouverte' };
String claimReason(Object? r) {
  final i = claimReasons.indexOf('$r');
  return i < 0 ? '$r' : claimReasonLabels[i];
}

Widget institutionsList({double width = 984, double height = 640}) => MobileList(
      provider: institutionsProvider,
      title: (r) => '${r['name']}',
      subtitle: (r) => [institutionKind(r['kind']), if ('${r['city'] ?? ''}'.isNotEmpty) '${r['city']}'].join(' · '),
      trailing: (r) => institutionStatus(r['status']),
      emptyText: 'Aucun établissement enregistré pour le moment.',
      width: width,
      height: height,
    );

Widget departmentsList({double width = 342, double height = 600}) => MobileList(
      provider: departmentsListProvider,
      where: (r) => '${r['status']}' == 'verified', // déjà filtré par le serveur ; garde-fou si un compte du département voit aussi les propositions
      title: (r) => '${r['name']}',
      subtitle: (r) => '${(r['institutions'] as Map?)?['name'] ?? ''}',
      emptyText: 'Aucun département publié pour le moment.',
      width: width,
      height: height,
    );

Widget wishesMarket({double width = 342, double height = 600}) => MobileList(
      provider: wishesListProvider,
      where: (r) => '${r['status']}' == 'approved' || '${r['status']}' == 'scheduled',
      title: (r) => '${r['title']}',
      subtitle: (r) => [if (r['price'] != null) fcfa((r['price'] as num).toInt()), if (r['threshold'] != null) 'seuil : ${r['threshold']} personnes'].join(' · '),
      emptyText: 'Aucun vœu ouvert pour le moment.\nLes vœux validés par l’administration apparaissent ici.',
      width: width,
      height: height,
    );

Widget livesAgenda({double width = 342, double height = 600}) => MobileList(
      provider: livesListProvider,
      where: (r) => '${r['status']}' == 'scheduled',
      title: (r) => '${r['title']}',
      subtitle: (r) => [if ('${r['starts_at'] ?? ''}'.isNotEmpty) '${r['starts_at']}', if ('${r['product_title'] ?? ''}'.isNotEmpty) '${r['product_title']}'].join(' · '),
      emptyText: 'Aucun live programmé pour le moment.',
      width: width,
      height: height,
    );

Widget claimsTable({double width = 984, double height = 640}) => MobileList(
      provider: claimsListProvider,
      title: (r) => claimReason(r['reason']),
      subtitle: (r) => '${r['details']} · ${dateCourte(r['created_at'])}',
      trailing: (r) => claimStatus(r['status']),
      emptyText: 'Aucune réclamation pour le moment.',
      width: width,
      height: height,
    );

Widget declaredPayments({double width = 984, double height = 640}) => MobileList(
      provider: financePaymentsProvider,
      title: (r) => '${r['reference']} · ${r['order']}',
      subtitle: (r) => '${r['method'] ?? '—'} · ${fcfa(((r['amount'] as num?) ?? 0).toInt())}',
      trailing: (r) => paymentState(r['state']),
      emptyText: 'Aucun paiement déclaré pour le moment.',
      width: width,
      height: height,
    );

Widget certificatesWide({double width = 984, double height = 640}) => MobileList(
      provider: certificatesProvider,
      title: (r) => '${r['subject_title']}',
      subtitle: (r) => 'Certificat n° ${r['code']} · ${r['holder_name'] ?? ''} · délivré le ${dateCourte(r['issued_at'])}',
      trailing: (r) => r['revoked'] == true ? 'Révoqué' : 'Valide',
      emptyText: 'Aucun certificat émis pour le moment.',
      width: width,
      height: height,
    );
