/// Hors navigateur (tests, mobile) : aucune source d'événement réseau ; l'application se considère en ligne.
bool browserOnline() => true;

void listenConnectivity(void Function(bool online) onChange) {}
