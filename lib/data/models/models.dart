/// Modèles partagés. Les données viennent des dépôts de démonstration (lib/data/demo),
/// remplaçables plus tard par une API.
library;

enum ListingStatus { published, inReview, draft }

enum ListingType { product, service, project }

class Product {
  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.seller,
    required this.department,
    this.institution = 'IUT de Douala',
    this.image,
    this.status = ListingStatus.published,
    this.type = ListingType.product,
    this.updated = '12/10/2026',
  });

  final String id;
  final String title;
  final int price;
  final String seller;
  final String department;
  final String institution;
  final String? image;
  final ListingStatus status;
  final ListingType type;
  final String updated;
}

enum Progress { done, current, upcoming }

class WorkflowStep {
  const WorkflowStep(this.title, this.detail, this.progress);

  final String title;
  final String detail;
  final Progress progress;
}

enum CheckState { passed, pending, failed }

class CheckItem {
  const CheckItem(this.label, this.state);

  final String label;
  final CheckState state;
}

class Payment {
  const Payment({
    required this.orderId,
    required this.method,
    required this.amount,
    required this.reference,
    this.remaining = '',
    this.receiptNo = '',
    this.date = '',
    this.seller = '',
    this.pickup = '',
    this.failureReason = '',
    this.attempt = '',
  });

  final String orderId;
  final String method;
  final int amount;
  final String reference;
  final String remaining;
  final String receiptNo;
  final String date;
  final String seller;
  final String pickup;
  final String failureReason;
  final String attempt;
}

class PaymentMethod {
  const PaymentMethod(this.id, this.label, this.badge);

  final String id;
  final String label;
  final String badge;
}

class InvoiceLine {
  const InvoiceLine(this.label, this.qty, this.amount);

  final String label;
  final int qty;
  final int amount;
}

class Invoice {
  const Invoice({required this.number, required this.date, required this.lines, required this.fees, required this.taxes});

  final String number;
  final String date;
  final List<InvoiceLine> lines;
  final int fees;
  final int taxes;

  int get gross => lines.fold(0, (s, l) => s + l.amount);
}

/// Élément de liste générique : titre, détail, statut coloré.
enum Tone { success, warning, error, accent, neutral }

class StatusItem {
  const StatusItem(this.title, this.detail, this.status, this.tone, {this.extra = ''});

  final String title;
  final String detail;
  final String status;
  final Tone tone;
  final String extra;
}

class SocialLink {
  const SocialLink(this.network, this.handle, this.enabled, this.asset);

  final String network;
  final String handle;
  final bool enabled;
  final String asset;
}

class LabeledValue {
  const LabeledValue(this.label, this.value, {this.tone});

  final String label;
  final String value;
  final Tone? tone;
}

class Skill {
  const Skill(this.name, this.level, this.value);

  final String name;
  final String level;
  final double value;
}

class Member {
  const Member(this.name, this.role, this.rights);

  final String name;
  final String role;
  final String rights;
}

class Kpi {
  const Kpi(this.label, this.value, {this.delta, this.tone = Tone.success, this.status});

  final String label;
  final String value;
  final String? delta;
  final Tone tone;
  final String? status;
}

class MediaItem {
  const MediaItem(this.name, this.kind, this.image, {this.public = true});

  final String name;
  final String kind;
  final String image;
  final bool public;
}

class Talent {
  const Talent(this.name, this.speciality, this.image, this.match);

  final String name;
  final String speciality;
  final String image;
  final int match;
}
