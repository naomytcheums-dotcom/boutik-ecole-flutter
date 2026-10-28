import '../../../core/utils/validators.dart';
import '../../common/common.dart';

/// 275 · Déposer un produit, étape 2 sur 4 : validation des champs et messages d'erreur.
class DepotProduitErreursScreen extends ConsumerStatefulWidget {
  const DepotProduitErreursScreen({super.key, this.showInitialErrors = true});

  /// La maquette montre l'état « 3 champs à corriger » : on l'affiche dès l'ouverture.
  final bool showInitialErrors;

  @override
  ConsumerState<DepotProduitErreursScreen> createState() => _DepotProduitErreursScreenState();
}

class _DepotProduitErreursScreenState extends ConsumerState<DepotProduitErreursScreen> {
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _category = TextEditingController(text: 'Mobilier · Bois recyclé');
  // Fichier simulé de la maquette (sélecteur de fichier réel à brancher).
  ({String name, int bytes})? _photo = (name: 'image-trop-lourde.png', bytes: 9856000);
  late bool _submitted = widget.showInitialErrors;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _category.dispose();
    super.dispose();
  }

  String? get _titleError => _submitted ? Validators.title(_title.text) : null;
  String? get _priceError => _submitted ? Validators.priceFcfa(_price.text) : null;
  String? get _photoError => !_submitted
      ? null
      : _photo == null
      ? 'Ajoutez une photo principale.'
      : Validators.image(_photo!.name, _photo!.bytes);

  int get _errorCount => [_titleError, _priceError, _photoError].whereType<String>().length;

  void _continue() {
    setState(() => _submitted = true);
    if (_errorCount == 0) context.openScreen('279');
  }

  String _size(int b) => '${(b / 1048576).toStringAsFixed(1).replaceAll('.', ',')} Mo';

  @override
  Widget build(BuildContext context) {
    return DetailScreen(
      title: 'Déposer un produit',
      subtitle: 'Étape 2 sur 4 · Informations',
      action: 'Continuer',
      onAction: _continue,
      children: [
        TextFieldWithError(
          label: 'Titre du produit',
          controller: _title,
          errorText: _titleError,
          onChanged: (_) => setState(() {}),
        ),
        gap16,
        TextFieldWithError(
          label: 'Prix (FCFA)',
          hint: 'Ex : 25 000',
          controller: _price,
          keyboardType: TextInputType.number,
          errorText: _priceError,
          onChanged: (_) => setState(() {}),
        ),
        gap16,
        TextFieldWithError(label: 'Catégorie', controller: _category, readOnly: true),
        gap24,
        TextFieldWithError(
          label: 'Photo principale',
          controller: TextEditingController(text: _photo == null ? '' : '${_photo!.name} · ${_size(_photo!.bytes)}'),
          hint: 'Choisir une image (5 Mo max.)',
          readOnly: true,
          errorText: _photoError,
          onTap: () => setState(() => _photo = (name: 'lampe-face.jpg', bytes: 2300000)),
        ),
        if (_errorCount > 0) ...[
          gap24,
          InfoNote(
            '$_errorCount ${_errorCount > 1 ? 'champs' : 'champ'} à corriger avant de continuer. Votre brouillon est enregistré.',
            icon: AppIcons.triangleAlert,
            tone: NoteTone.error,
          ),
        ],
      ],
    );
  }
}
